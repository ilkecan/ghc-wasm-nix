{
  lib,
  mkDerivation,
  base,
  Cabal,
}:

# Removing `--with-gcc` or `--with-ld` makes this check fail. Removing
# `--with-ar` or `--with-strip` currently does not, because their nixpkgs
# fallbacks also work.
mkDerivation {
  pname = "bindist-toolchain-regression";
  version = "0.0.0.0";

  src = ./.;

  # Building the library archive invokes Cabal's configured `ar`.
  isLibrary = true;

  # Building the GHCi object invokes Cabal's configured linker with `-r`.
  enableLibraryForGhci = true;
  doHaddock = false;

  # Installing the library invokes Cabal's configured strip tool.
  dontStrip = false;

  setupHaskellDepends = [
    base
    Cabal
  ];
  libraryHaskellDepends = [ base ];

  license = lib.licenses.bsd3;
}
