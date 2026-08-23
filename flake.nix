{
  description = "A small nixpkgs consumer for GHC's wasm backend";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    ghc-wasm-meta = {
      url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      flake-parts,
      ghc-wasm-meta,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      mkGhc =
        {
          pkgs,
        }:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          metaPackages = ghc-wasm-meta.packages.${system};
        in
        import ./lib/ghc-bindist.nix { inherit (pkgs) lib; } {
          ghc = metaPackages."wasm32-wasi-ghc-9_14";
          inherit (metaPackages) nodejs;
          wasiSdk = metaPackages.wasi-sdk;
          version = "9.14.1.20260731";
        };

      mkPackageSetBase =
        {
          packageSetConfig,
          pkgs,
          stdenv,
        }:
        let
          ghc = mkGhc { inherit pkgs; };
        in
        import ./lib/package-set.nix { nixpkgsSrc = pkgs.path; } {
          inherit ghc packageSetConfig stdenv;
          buildHaskellPackages = pkgs.haskell.packages.ghc9141;
          wasmPkgs = pkgs.pkgsCross.wasi32;
        };

      mkRawPackageSet =
        {
          packageSetConfig ? (_final: _prev: { }),
          pkgs,
        }:
        mkPackageSetBase {
          inherit packageSetConfig pkgs;
          stdenv = pkgs.pkgsCross.wasi32.stdenv;
        };

      mkPackageSet =
        {
          packageSetConfig ? (_final: _prev: { }),
          pkgs,
        }:
        let
          inherit (pkgs) lib;
          wasmPkgs = pkgs.pkgsCross.wasi32;
        in
        mkPackageSetBase {
          inherit pkgs;
          packageSetConfig = lib.composeManyExtensions [
            (import ./lib/configuration-wasm.nix)
            packageSetConfig
          ];
          # remove the static adapter's Cabal flags so configuration-wasm.nix
          # can enable shared libraries
          stdenv = wasmPkgs.stdenvAdapters.overrideMkDerivationArgs (oldAttrs: {
            configureFlags = lib.subtractLists [
              "--enable-static"
              "--disable-shared"
            ] (oldAttrs.configureFlags or [ ]);
          }) wasmPkgs.stdenv;
        };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      # ghc-wasm-meta has to ship a bindist and nixpkgs has to compile natively
      systems = lib.intersectLists (lib.attrNames ghc-wasm-meta.packages) lib.systems.flakeExposed;

      flake = {
        lib = { inherit mkGhc mkPackageSet; };

        overlays.default = final: _prev: {
          haskellWasmPackages = mkPackageSet { pkgs = final; };
        };
      };

      perSystem =
        { pkgs, ... }:
        let
          haskellPackages = mkPackageSet { inherit pkgs; };
          inherit (haskellPackages) ghc;
          runtimeFixture = haskellPackages.callPackage ./checks/runtime { };
          runtimeExpected = pkgs.writeText "runtime-expected" ''
            wasm runtime ran
          '';
        in
        {
          packages = {
            inherit ghc;
            default = ghc;

            haddock-repro = import ./repros/haddock.nix {
              inherit pkgs;
              mkPackageSet = mkRawPackageSet;
            };

            interpreter-repro = import ./repros/interpreter.nix {
              inherit pkgs;
              mkPackageSet = mkRawPackageSet;
            };

            shared-libraries-repro = import ./repros/shared-libraries.nix {
              inherit pkgs;
              mkPackageSet = mkRawPackageSet;
            };
          };

          checks = {
            bindist-toolchain = haskellPackages.callPackage ./checks/bindist-toolchain { };
            haddock = haskellPackages.callPackage ./checks/haddock { };
            runtime-wasmtime = pkgs.testers.testEqualContents {
              assertion = "Wasmtime runs the wasm fixture";
              actual = pkgs.runCommand "runtime-wasmtime-output" { } ''
                ${pkgs.wasmtime}/bin/wasmtime run -C cache=n \
                  ${runtimeFixture}/bin/runtime-fixture.wasm > "$out"
              '';
              expected = runtimeExpected;
            };
            runtime-wasmer = pkgs.testers.testEqualContents {
              assertion = "Wasmer runs the wasm fixture";
              actual = pkgs.runCommand "runtime-wasmer-output" { } ''
                ${pkgs.wasmer}/bin/wasmer run \
                  ${runtimeFixture}/bin/runtime-fixture.wasm > "$out"
              '';
              expected = runtimeExpected;
            };
            template-haskell = haskellPackages.callPackage ./checks/template-haskell { };
            shared-libraries = haskellPackages.callPackage ./checks/shared-libraries { };
          };
        };
    };
}
