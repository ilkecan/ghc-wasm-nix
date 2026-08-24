{
  mkPackageSet,
  pkgs,
}:

let
  haskellPackages = mkPackageSet {
    inherit pkgs;
    flavour = "9.14";
    packageSetConfig = final: prev: {
      mkDerivation =
        args:
        prev.mkDerivation (
          args
          // {
            # isolate Haddock from the wasm interpreter changes
            enableExternalInterpreter = false;
            enableLibraryProfiling = false;
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

haskellPackages.callPackage ../checks/haddock { }
