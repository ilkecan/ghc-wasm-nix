{
  lib,
  mkDerivation,
  base,
  Cabal,
}:

# Removing `--with-gcc` or `--with-ld` makes this check fail. Removing
# `--with-ar` currently does not, because the nixpkgs fallback also work.
mkDerivation {
  pname = "bindist-toolchain-regression";
  version = "0.0.0.0";

  src = ./.;

  # Building the library archive invokes Cabal's configured `ar`.
  isLibrary = true;

  # Building the GHCi object invokes Cabal's configured linker with `-r`.
  enableLibraryForGhci = true;
  doHaddock = false;

  setupHaskellDepends = [
    base
    Cabal
  ];
  libraryHaskellDepends = [ base ];

  license = lib.licenses.bsd3;
}
