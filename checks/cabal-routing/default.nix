# Behavioral Cabal routing check: configure a minimal package through the
# wrapper with only the wasm GHC on PATH.
{
  runCommand,
  jq,
  cabalWrapper,
  ghc,
  expectedConfig,
}:

runCommand "cabal-routing-check" {
  fixture = ./cabal-routing.cabal;

  nativeBuildInputs = [
    cabalWrapper
    ghc
    jq
  ];
} ''
  export HOME=$(mktemp -d)
  cp "$fixture" .
  config_path="$HOME/.ghc-wasm/.cabal/config"

  # The first invocation installs the exact seed for the default flavour.
  wasm32-wasi-cabal --version > /dev/null
  cmp "$config_path" "${expectedConfig}"

  # The seeded config enables secure Hackage repository discovery even in
  # offline mode, so ignore it to keep this sandboxed routing check network-free.
  wasm32-wasi-cabal --config-file=/dev/null build \
    --offline \
    --only-configure \
    exe:cabal-routing

  jq -e '.arch == "wasm32" and .os == "wasi"' \
    dist-newstyle/cache/plan.json > /dev/null

  touch "$out"
''
