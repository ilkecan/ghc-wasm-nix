# ghc-wasm-nix

ghc-wasm-nix integrates the prebuilt `wasm32-wasi` GHC bindists published by [`ghc-wasm-meta`][ghc-wasm-meta] with nixpkgs's Haskell infrastructure. It provides wasm-targeting compiler derivations and nixpkgs Haskell package sets configured for wasm without rebuilding GHC from source.

The resulting package sets support the usual nixpkgs Haskell interfaces, including `callCabal2nix`, `callHackage`, `shellFor` and package overrides.

[ghc-wasm-meta]: https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta

## Usage

Apply the default overlay and build packages with `haskellWasmPackages`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    ghc-wasm-nix = {
      url = "github:ilkecan/ghc-wasm-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      ghc-wasm-nix,
      nixpkgs,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ ghc-wasm-nix.overlays.default ];
      };
    in
    {
      packages.${system}.my-app =
        pkgs.haskellWasmPackages.callCabal2nix "my-app" ./. { };
    };
}
```

`haskellWasmPackages` uses the configured default compiler. Select another flavour with, for example, `pkgs.haskellWasm.packages.ghc912.callCabal2nix`. Executable components are installed as `$out/bin/<name>.wasm`.

## Interface

The overlay exposes a compiler attribute for every bindist available on the current Nix system, plus a corresponding lazily instantiated package-set attribute:

```nix
haskellWasm.compiler.ghc914
haskellWasm.packages.ghc914
haskellWasmPackages # alias of haskellWasm.packages.<default compiler attribute>
haskellWasm.lib.mkGhc { inherit pkgs; flavour = "9.12"; }
haskellWasm.lib.mkPackageSet { inherit pkgs; flavour = "9.12"; }
```

The flake also exposes compiler derivations directly:

```nix
packages.<system>.ghc914
packages.<system>.ghc # alias of packages.<system>.<default compiler attribute>
packages.<system>.default # alias of packages.<system>.ghc
```

### Library

The flake library exposes two constructors, `mkGhc` and `mkPackageSet`, through `ghc-wasm-nix.lib`. Applying the overlay also makes them available under `haskellWasm.lib`.

Both constructors accept `pkgs` and an upstream flavour name such as `"9.12"`. `mkPackageSet` additionally accepts `packageSetConfig` and an explicit `ghc`.

The constructors use upstream flavour names, while the compiler and package-set attributes exposed by the overlay use derived compiler-style names such as `ghc912`.

## Flavours and systems

The flake currently exposes `aarch64-darwin`, `aarch64-linux` and `x86_64-linux`.

| Flavour | Attribute | Systems | Haskell package set |
| --- | --- | --- | --- |
| gmp | `gmp` | `x86_64-linux` | no |
| 9.14 | `ghc914` | all exposed systems | yes |
| 9.12 | `ghc912` | all exposed systems | yes |
| 9.10 | `ghc910` | all exposed systems | yes |
| 9.8 | `ghc98` | `x86_64-linux` | yes |
| 9.6 | `ghc96` | `x86_64-linux` | yes |

Flavours identify upstream bindist streams, not immutable compiler snapshots. For example, `ghc914` resolves to the exact 9.14 bindist selected by the flake's locked `ghc-wasm-meta` input. The attribute follows later 9.14 patch builds when that input is updated.

The default flavour is selected in `flavours.nix` and is currently 9.14. `versions.json` records bindist versions and system availability from upstream. The `gmp` bindist is exposed as a compiler, but the locked nixpkgs does not yet provide the GHC 10.1 configuration needed to instantiate its package set.

## Current support

The checks for the default flavour cover:

- Haskell and C source builds through nixpkgs's Haskell builder
- Template Haskell, including splices that load package dependencies
- shared Haskell libraries and Haddock
- executables under Node.js, Wasmtime and Wasmer
- use of the C toolchain shipped with the bindist

These checks cover the integration paths above, not compatibility with every Haskell package. Individual packages must build for `wasm32-wasi` and use only APIs available under WASI; packages relying on unavailable platform facilities may fail to build.

Checks for other flavours validate bindist metadata and availability, but do not run the full package-set regressions. A listed bindist is therefore not a claim that every nixpkgs Haskell package works with that flavour.

Library profiling is disabled. GHC's wasm backend supports profiling, but using Template Haskell with profiling enabled requires both profiled and profiled-shared versions of the Haskell libraries in a package's dependency closure. Building these additional versions increases build cost, so this integration does not currently provide them.
