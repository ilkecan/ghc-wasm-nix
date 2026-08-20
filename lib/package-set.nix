# Instantiate nixpkgs's Haskell machinery with a wasm-targeting GHC.
{
  nixpkgsSrc,
}:

{
  buildHaskellPackages,
  ghc,
  packageSetConfig,
  wasmPkgs,
  compilerConfigFile ? "configuration-ghc-${wasmPkgs.lib.versions.majorMinor ghc.version}.x.nix",
}:

let
  haskellLib = wasmPkgs.haskell.lib.compose;

  # wasi32 uses the static stdenv adapter, which appends Cabal flags that
  # conflict with generic-builder.nix's wasm settings. This is independent of
  # the interpreter and Haddock changes under test.
  haskellStdenv = wasmPkgs.stdenvAdapters.overrideMkDerivationArgs (oldAttrs: {
    configureFlags = wasmPkgs.lib.subtractLists [
      "--enable-static"
      "--disable-shared"
    ] (oldAttrs.configureFlags or [ ]);
  }) wasmPkgs.stdenv;
in

wasmPkgs.callPackage (nixpkgsSrc + "/pkgs/development/haskell-modules") {
  inherit
    buildHaskellPackages
    ghc
    haskellLib
    packageSetConfig
    ;

  stdenv = haskellStdenv;

  compilerConfig = wasmPkgs.callPackage (
    nixpkgsSrc + "/pkgs/development/haskell-modules/${compilerConfigFile}"
  ) { inherit haskellLib; };
}
