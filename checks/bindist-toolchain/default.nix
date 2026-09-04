# All four SDK tools are exercised. Falling back to nixpkgs fails for `gcc` and
# `ld`, but succeeds for `ar` and `strip`. Only the routing assertion below
# detects the latter two regressions.
{
  lib,
  mkDerivation,
  base,
  Cabal,
  ghc,
}:

let
  expectedToolRouting = lib.concatLines [
    "ar=${ghc.wasiSdk}/bin/llvm-ar"
    "gcc=${ghc.wasiSdk}/bin/wasm32-wasi-clang"
    "ghc-pkg=${ghc.targetPrefix}ghc-pkg"
    "ghc=${ghc.targetPrefix}ghc"
    "haddock=${ghc.targetPrefix}haddock"
    "hsc2hs=${ghc.targetPrefix}hsc2hs"
    "ld=${ghc.wasiSdk}/bin/wasm-ld"
    "strip=${ghc.wasiSdk}/bin/llvm-strip"
  ];
in
mkDerivation {
  pname = "bindist-toolchain-regression";
  version = "0.0.0.0";

  src = ./.;

  # Building the library archive invokes Cabal's configured `ar`.
  isLibrary = true;

  # Building the GHCi object invokes Cabal's configured linker with `-r`.
  enableLibraryForGhci = true;

  # Installing the library invokes Cabal's configured strip tool.
  dontStrip = false;

  setupHaskellDepends = [
    base
    Cabal
  ];
  libraryHaskellDepends = [ base ];

  # Check the effective routing after generic-builder and its hooks have added
  # their configure flags. Cabal uses the last value for repeated options.
  postConfigure = ''
    declare -A configuredWithPrograms=()
    for flag in $configureFlags; do
      case "$flag" in
        --with-*=*)
          name="''${flag%%=*}"
          configuredWithPrograms["''${name#--with-}"]="''${flag#*=}"
          ;;
      esac
    done

    if ! routingDiff=$(
      diff \
        --unchanged-line-format="" \
        --old-line-format='expected: %L' \
        --new-line-format='actual: %L' \
        <(printf '%s' ${lib.escapeShellArg expectedToolRouting} | sort) \
        <(
          for name in "''${!configuredWithPrograms[@]}"; do
            printf '%s=%s\n' "$name" "''${configuredWithPrograms[$name]}"
          done | sort
        )
    ); then
      printf 'bindist tool routing changed:\n%s\n' "$routingDiff" >&2
      exit 1
    fi
  '';
}
