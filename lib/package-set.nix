# Instantiate nixpkgs's Haskell machinery with a wasm-targeting GHC.
{
  nixpkgsSrc,
}:

{
  buildHaskellPackages,
  ghc,
  packageSetConfig,
  stdenv,
  wasmPkgs,
  compilerConfigFile ? "configuration-ghc-${wasmPkgs.lib.versions.majorMinor ghc.version}.x.nix",
}:

let
  haskellLib = wasmPkgs.haskell.lib.compose;
in

wasmPkgs.callPackage (nixpkgsSrc + "/pkgs/development/haskell-modules") {
  inherit
    buildHaskellPackages
    ghc
    haskellLib
    packageSetConfig
    stdenv
    ;

  compilerConfig = wasmPkgs.callPackage (
    nixpkgsSrc + "/pkgs/development/haskell-modules/${compilerConfigFile}"
  ) { inherit haskellLib; };
}
