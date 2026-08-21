{
  lib,
  mkDerivation,
  base,
}:

mkDerivation {
  pname = "cross-haddock-repro";
  version = "0.0.0.0";

  src = ./.;

  isLibrary = true;
  isExecutable = false;

  libraryHaskellDepends = [ base ];

  license = lib.licenses.bsd3;
}
