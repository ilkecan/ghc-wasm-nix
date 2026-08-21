{
  mkPackageSet,
  pkgs,
}:

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

haskellPackages.callPackage ./default.nix { }
