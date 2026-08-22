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
            # keep unrelated wasm integration failures out of this repro
            doHaddock = false;
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

  dependency = haskellPackages.callPackage ./dependency { };
in

haskellPackages.callPackage ./default.nix { inherit dependency; }
