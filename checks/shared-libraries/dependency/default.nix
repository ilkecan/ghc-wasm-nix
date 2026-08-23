{
  mkDerivation,
  base,
  template-haskell,
}:

mkDerivation {
  pname = "shared-libraries-dependency-repro";
  version = "0.0.0.0";

  src = ./.;

  isLibrary = true;
  isExecutable = false;
  doHaddock = false;

  libraryHaskellDepends = [
    base
    template-haskell
  ];
}
