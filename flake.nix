{
  description = "A small nixpkgs consumer for GHC's wasm backend";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    ghc-wasm-meta = {
      url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ghc-wasm-meta,
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

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
    {
      lib = { inherit mkGhc mkPackageSet; };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          haskellPackages = mkPackageSet { inherit pkgs; };
          inherit (haskellPackages) ghc;
        in
        {
          inherit ghc;
          default = ghc;

          haddock-check = self.checks.${system}.haddock;
          interpreter-check = self.checks.${system}.interpreter;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          haddock =
            let
              haskellPackages = mkPackageSet {
                inherit pkgs;
                packageSetConfig = final: prev: {
                  mkDerivation =
                    args:
                    prev.mkDerivation (
                      args
                      // {
                        # isolate Haddock from the wasm interpreter changes
                        doHaddock = true;
                        enableExternalInterpreter = false;
                        enableLibraryProfiling = false;
                        enableSharedLibraries = true;
                        configureFlags = (args.configureFlags or [ ]) ++ [
                          "--with-gcc=${final.ghc.wasiSdk}/bin/wasm32-wasi-clang"
                          "--with-ar=${final.ghc.wasiSdk}/bin/llvm-ar"
                          "--with-ld=${final.ghc.wasiSdk}/bin/wasm-ld"
                        ];
                      }
                    );
                };
              };
            in
            haskellPackages.callPackage ./checks/haddock { };

          interpreter =
            let
              haskellPackages = mkPackageSet {
                inherit pkgs;
                packageSetConfig = final: prev: {
                  # ghc-wasm-meta wraps GHC with Node. Remove that wrapper so
                  # this check verifies that nixpkgs supplies Node to the build
                  # environment.
                  ghc = prev.ghc.overrideAttrs {
                    postInstall = "";
                  };

                  mkDerivation =
                    args:
                    prev.mkDerivation (
                      args
                      // {
                        # keep unrelated wasm integration issues out of this check
                        doHaddock = false;
                        enableSharedLibraries = true;
                        configureFlags = (args.configureFlags or [ ]) ++ [
                          "--with-gcc=${final.ghc.wasiSdk}/bin/wasm32-wasi-clang"
                          "--with-ar=${final.ghc.wasiSdk}/bin/llvm-ar"
                          "--with-ld=${final.ghc.wasiSdk}/bin/wasm-ld"
                        ];
                      }
                    );
                };
              };
            in
            haskellPackages.callPackage ./checks/interpreter { };
        }
      );
    };
}
