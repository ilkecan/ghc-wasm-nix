{
  lib,
  mkDerivation,
  base,
  template-haskell,
}:

mkDerivation {
  pname = "wasm-interpreter-repro";
  version = "0.0.0.0";

  src = ./.;

  isLibrary = true;
  isExecutable = false;
  doHaddock = false;

  libraryHaskellDepends = [
    base
    template-haskell
  ];

  license = lib.licenses.bsd3;
}
