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
              "--with-gcc=${final.ghc.wasiSdk}/bin/wasm32-wasi-clang"
              "--with-ar=${final.ghc.wasiSdk}/bin/llvm-ar"
              "--with-ld=${final.ghc.wasiSdk}/bin/wasm-ld"
            ];
          }
        );
    };
  };

  dependency = haskellPackages.callPackage ./dependency { };
in

haskellPackages.callPackage ./default.nix { inherit dependency; }
