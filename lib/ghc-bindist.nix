# Adapt a ghc-wasm-meta bindist to the compiler interface expected by nixpkgs's
# Haskell package set.
{ lib }:

{
  ghc,
  version,
  wasiSdk,
  nodejs,
  targetPrefix ? "wasm32-wasi-",
}:

ghc.overrideAttrs (oldAttrs: {
  inherit version;

  passthru = (oldAttrs.passthru or { }) // {
    inherit targetPrefix version;

    # follows nixpkgs's own *-binary.nix derivations
    enableShared = true;
    llvmPackages = null;
    haskellCompilerName = "ghc-${version}";
    hadrian = null;
    hasHaddock = true;

    inherit wasiSdk nodejs;
  };

  meta = (oldAttrs.meta or { }) // {
    description = "GHC ${version} targeting wasm32-wasi (upstream bindist)";
    license = lib.licenses.bsd3;
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode # prebuilt wasm code shipped with the compiler
      binaryNativeCode # prebuilt executables for the build machine
    ];
  };
})
