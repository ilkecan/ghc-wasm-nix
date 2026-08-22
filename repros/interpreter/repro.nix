{
  mkPackageSet,
  pkgs,
}:

let
  haskellPackages = mkPackageSet {
    inherit pkgs;
    packageSetConfig = final: prev: {
      # ghc-wasm-meta wraps GHC with Node. Remove that wrapper so this repro
      # verifies that nixpkgs supplies Node to the build environment.
      ghc = prev.ghc.overrideAttrs {
        postInstall = "";
      };

      mkDerivation =
        args:
        prev.mkDerivation (
          args
          // {
            # keep unrelated wasm integration issues out of this repro
            doHaddock = false;
            enableSharedLibraries = true;
            configureFlags = (args.configureFlags or [ ]) ++ [
              "--with-ar=${final.ghc.wasiSdk}/bin/llvm-ar"
              "--with-gcc=${final.ghc.wasiSdk}/bin/wasm32-wasi-clang"
              "--with-ld=${final.ghc.wasiSdk}/bin/wasm-ld"
              "--with-strip=${final.ghc.wasiSdk}/bin/llvm-strip"
            ];
          }
        );
    };
  };
in

haskellPackages.callPackage ./default.nix { }
