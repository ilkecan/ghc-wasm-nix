# Build a `wasm32-wasi-cabal` wrapper around nixpkgs cabal-install.
# Behavior reference: ghc-wasm-meta/pkgs/wasm32-wasi-cabal.nix.
{ cabal-install, lib, writeShellScriptBin, flavour, configFile }:

let
  cabalArgs = [
    "--with-compiler=wasm32-wasi-ghc"
    "--with-hc-pkg=wasm32-wasi-ghc-pkg"
    "--with-hsc2hs=wasm32-wasi-hsc2hs"
  ] ++ lib.optional (
    !(lib.elem flavour [ "9.6" "9.8" ])
  ) "--with-haddock=wasm32-wasi-haddock";
  cabalArgsShell = lib.concatMapStringsSep " " lib.escapeShellArg cabalArgs;
in
writeShellScriptBin "wasm32-wasi-cabal" ''
  export CABAL_DIR="''${CABAL_DIR:-$HOME/.ghc-wasm/.cabal}"
  config_path="$CABAL_DIR/config"

  if [ ! -e "$config_path" ]; then
    mkdir -p "$CABAL_DIR"
    cp "${configFile}" "$config_path"
    chmod u+w "$config_path"
  fi

  exec ${cabal-install}/bin/cabal ${cabalArgsShell} "$@"
''
