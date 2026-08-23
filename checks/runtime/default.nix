{
  mkDerivation,
  base,
}:

mkDerivation {
  pname = "runtime-fixture";
  version = "0.0.0.0";

  src = ./.;

  isLibrary = false;
  isExecutable = true;
  doHaddock = false;

  executableHaskellDepends = [ base ];
}
