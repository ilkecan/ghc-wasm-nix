# Contributing

## Validation

Evaluate the checks for every exposed system and run them for your current system:

```sh
nix flake check --all-systems
```

Changes to package-set behavior should update, or add a check under `checks/` when the affected behavior is not already covered.

## Updating compiler metadata

The updater reads the `ghc-wasm-meta` flake input. To refresh compiler metadata, update the input first:

```sh
nix flake update ghc-wasm-meta
```

Then regenerate `versions.json` from `ghc-wasm-meta`'s ghcup metadata:

```sh
nix run .#update-versions
```

Do not edit `versions.json` by hand; commit the generated file.

`flavours.nix` contains maintainer-owned policy and currently selects the default flavour. Do not change it during a routine metadata update unless you intentionally want to change that policy.
