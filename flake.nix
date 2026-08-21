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

      mkPackageSet =
        {
          packageSetConfig ? (_final: _prev: { }),
          pkgs,
        }:
        let
          ghc = mkGhc { inherit pkgs; };
        in
        import ./lib/package-set.nix { nixpkgsSrc = pkgs.path; } {
          inherit ghc packageSetConfig;
          buildHaskellPackages = pkgs.haskell.packages.ghc9141;
          wasmPkgs = pkgs.pkgsCross.wasi32;
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
        {
          packages =
            let
              haskellPackages = mkPackageSet { inherit pkgs; };
              inherit (haskellPackages) ghc;
            in
            {
              inherit ghc;
              default = ghc;

              haddock-repro = import ./repros/haddock/repro.nix {
                inherit mkPackageSet pkgs;
              };

              interpreter-repro = import ./repros/interpreter/repro.nix {
                inherit mkPackageSet pkgs;
              };

              shared-libraries-repro = import ./repros/shared-libraries/repro.nix {
                inherit mkPackageSet pkgs;
              };
            };

          checks = { };
        };
    };
}
