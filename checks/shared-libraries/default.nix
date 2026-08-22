{
  lib,
  mkDerivation,
  base,
  dependency,
  template-haskell,
}:

mkDerivation {
  pname = "shared-libraries-repro";
  version = "0.0.0.0";

  src = ./.;

  isLibrary = true;
  isExecutable = false;
  doHaddock = false;

  libraryHaskellDepends = [
    base
    dependency
    template-haskell
  ];

  license = lib.licenses.bsd3;
}
