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
            # keep unrelated wasm integration failures out of this repro
            enableExternalInterpreter = false;
            enableLibraryProfiling = false;
            buildTools = (args.buildTools or [ ]) ++ [ final.ghc.nodejs ];
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

haskellPackages.callPackage ../checks/shared-libraries { }
