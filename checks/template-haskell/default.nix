{
  lib,
  mkDerivation,
  base,
  template-haskell,
}:

mkDerivation {
  pname = "template-haskell-fixture";
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
