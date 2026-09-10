{
  description = "A small nixpkgs consumer for GHC's wasm backend";

  inputs = {
    nixpkgs.url = "nixpkgs-unstable";

    flake-parts = {
      url = "flake-parts";
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

      compilers = import ./lib/compilers.nix { inherit (nixpkgs) lib; } {
        versions = builtins.fromJSON (builtins.readFile ./versions.json);
        flavours = import ./flavours.nix;
      };

      mkGhc =
        {
          pkgs,
          flavour ? compilers.default.flavour,
        }:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          metaPackages = ghc-wasm-meta.packages.${system};
          spec = compilers.all.${flavour};
        in
        import ./lib/ghc-bindist.nix { inherit (pkgs) lib; } {
          ghc = metaPackages.${spec.metaAttr};
          wasiSdk = metaPackages.wasi-sdk;
          inherit (spec) version;
        };

      mkCompilerPackage = pkgs: flavour: spec:
        lib.nameValuePair spec.attrName (mkGhc { inherit pkgs flavour; });

      mkCompilerPackages = pkgs:
        lib.mapAttrs' (mkCompilerPackage pkgs) (compilers.availableFor pkgs.stdenv.hostPlatform.system);

      mkPackageSetBase =
        {
          flavour,
          packageSetConfig,
          pkgs,
          stdenv,
          ghc,
        }:
        let
          spec = compilers.all.${flavour};
          buildHaskellPackages =
            if pkgs.haskell.packages ? ${spec.bootstrapAttr} then
              pkgs.haskell.packages.${spec.bootstrapAttr}
            else if spec.fallbackAttr != null then
              if pkgs.haskell.packages ? ${spec.fallbackAttr} then
                lib.warn ''
                  ghc-wasm ${flavour}: nixpkgs does not provide bootstrap ${spec.bootstrapAttr} for bindist ${spec.version}; falling back to haskell.packages.${spec.fallbackAttr}
                ''
                pkgs.haskell.packages.${spec.fallbackAttr}
              else
                throw ''
                  ghc-wasm ${flavour}: neither bootstrap ${spec.bootstrapAttr} nor fallback ${spec.fallbackAttr} exists in nixpkgs
                ''
            else
              throw ''
                ghc-wasm ${flavour}: bootstrap ${spec.bootstrapAttr} does not exist in nixpkgs and this flavour has no fallback bootstrap
              '';
        in
        import ./lib/package-set.nix { nixpkgsSrc = pkgs.path; } {
          inherit ghc packageSetConfig stdenv buildHaskellPackages;
          compilerConfigFile = spec.compilerConfigFile;
          wasmPkgs = pkgs.pkgsCross.wasi32;
        };

      mkRawPackageSet =
        {
          pkgs,
          flavour ? compilers.default.flavour,
          packageSetConfig ? (_final: _prev: { }),
          ghc ? mkGhc { inherit flavour pkgs; },
        }:
        mkPackageSetBase {
          inherit flavour packageSetConfig pkgs ghc;
          stdenv = pkgs.pkgsCross.wasi32.stdenv;
        };

      mkPackageSet =
        {
          pkgs,
          flavour ? compilers.default.flavour,
          packageSetConfig ? (_final: _prev: { }),
          ghc ? mkGhc { inherit flavour pkgs; },
        }:
        let
          inherit (pkgs) lib;
          wasmPkgs = pkgs.pkgsCross.wasi32;
        in
        mkPackageSetBase {
          inherit flavour pkgs ghc;
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

      # Deliberately unfiltered by nixpkgs support; unsupported flavours fail
      # lazily on access.
      mkFlavourPackageSets = pkgs:
        let
          availableCompilers = compilers.availableFor pkgs.stdenv.hostPlatform.system;
        in
        compilerSet:
        lib.mapAttrs'
          (flavour: spec:
            lib.nameValuePair spec.attrName (
              mkPackageSet {
                inherit flavour pkgs;
                ghc = compilerSet.${spec.attrName};
              }
            )
          )
          availableCompilers;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Build the flake on every system exposed by nixpkgs for which
      # ghc-wasm-meta publishes at least one compiler bindist.
      systems = lib.intersectLists compilers.systems lib.systems.flakeExposed;

      flake = {
        lib = { inherit mkGhc mkPackageSet; };

        overlays.default = final: _prev:
          {
            haskellWasm.lib = { inherit mkGhc mkPackageSet; };

            # Mirrors `pkgs.haskell.compiler.*` and `pkgs.haskell.packages.*`.
            haskellWasm.compiler = mkCompilerPackages final;
            haskellWasm.packages = mkFlavourPackageSets final final.haskellWasm.compiler;
            haskellWasmPackages = final.haskellWasm.packages.${compilers.default.attrName};
          };
      };

      perSystem =
        { pkgs, system, config, ... }:
        let
          haskellPackages = mkPackageSet { inherit pkgs; };
          runtimeFixture = haskellPackages.callPackage ./checks/runtime { };
          runtimeExpected = pkgs.writeText "runtime-expected" ''
            wasm runtime ran
          '';
          mkBindistMetadataCheck = flavour: spec:
            let
              inherit (spec) attrName;
              metaPackages = ghc-wasm-meta.packages.${system};
              bindist = metaPackages.${spec.metaAttr};

              # ghc-wasm-meta exposes a flavour attribute even on systems where
              # its bindist is unavailable. Force drvPath to verify that
              # versions.json advertises an instantiable bindist for this
              # flavour and system. stringLength discards the string context,
              # so the bindist cannot become a build dependency.
              bindistOk = lib.tryEval (lib.stringLength bindist.drvPath);
            in
            {
              name = "bindist-metadata-${attrName}";
              value =
                if !bindistOk.success then
                  throw "bindist-metadata-${attrName}: could not instantiate ghc-wasm-meta bindist ${spec.metaAttr} for ${system} (flavour ${flavour})"
                else
                  pkgs.writeText "bindist-metadata-${attrName}-check" ''
                    flavour ${flavour}
                    version ${spec.version}
                    bindist ${spec.metaAttr}
                    system ${system}
                  '';
            };
        in
        {
          apps = {
            update-versions = {
              program = lib.getExe (
                pkgs.writeShellApplication {
                  name = "update-versions";
                  runtimeInputs = with pkgs; [ nushell ];
                  text = ''exec ${./scripts/update-versions.nu} ${ghc-wasm-meta} > "''${1:-versions.json}"'';
                }
              );
              meta.description = "Update compiler metadata from ghc-wasm-meta's ghcup YAML";
            };
          };

          checks = lib.mapAttrs' mkBindistMetadataCheck (compilers.availableFor system) // {
            bindist-toolchain = haskellPackages.callPackage ./checks/bindist-toolchain { };
            haddock = haskellPackages.callPackage ./checks/haddock { };

            runtime-node = pkgs.testers.testEqualContents {
              assertion = "Node runs the wasm fixture";
              actual = pkgs.runCommand "runtime-node-output" { } ''
                ${lib.getExe pkgs.nodejs} ${./checks/runtime/run-node.mjs} \
                  ${runtimeFixture}/bin/runtime-fixture.wasm > "$out"
              '';
              expected = runtimeExpected;
            };

            runtime-wasmedge = pkgs.testers.testEqualContents {
              assertion = "WasmEdge runs the wasm fixture";
              actual = pkgs.runCommand "runtime-wasmedge-output" { } ''
                ${lib.getExe pkgs.wasmedge} run \
                  ${runtimeFixture}/bin/runtime-fixture.wasm > "$out"
              '';
              expected = runtimeExpected;
            };

            runtime-wasmer = pkgs.testers.testEqualContents {
              assertion = "Wasmer runs the wasm fixture";
              actual = pkgs.runCommand "runtime-wasmer-output" { } ''
                ${lib.getExe pkgs.wasmer} run \
                  ${runtimeFixture}/bin/runtime-fixture.wasm > "$out"
              '';
              expected = runtimeExpected;
            };

            runtime-wasmtime = pkgs.testers.testEqualContents {
              assertion = "Wasmtime runs the wasm fixture";
              actual = pkgs.runCommand "runtime-wasmtime-output" { } ''
                ${lib.getExe pkgs.wasmtime} run -C cache=n \
                  ${runtimeFixture}/bin/runtime-fixture.wasm > "$out"
              '';
              expected = runtimeExpected;
            };

            shared-libraries = haskellPackages.callPackage ./checks/shared-libraries { };
            template-haskell = haskellPackages.callPackage ./checks/template-haskell { };
          };

          packages = mkCompilerPackages pkgs // {
            ghc = config.packages.${compilers.default.attrName};
            default = config.packages.ghc;

            shared-libraries-repro = import ./repros/shared-libraries.nix {
              inherit pkgs;
              mkPackageSet = mkRawPackageSet;
            };
          };

          legacyPackages = mkFlavourPackageSets pkgs config.packages;
        };
    };
}
