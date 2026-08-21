# Overrides for using GHC's wasm backend with nixpkgs's Haskell builder.
#
# nixpkgs has configuration files for Windows and GHCJS, but no equivalent for
# wasm.
#
# Upstream status:
# - nixpkgs#553410: wasm interpreter setup, Node, and profiling defaults.
# - nixpkgs#553415: target Haddock selection for cross builds.

final: prev: {
  # apply these generic-builder arguments to every package in the set
  mkDerivation =
    args:
    prev.mkDerivation (
      args
      // {
        # This option makes nixpkgs pass an iserv-proxy wrapper to GHC. The
        # wasm compiler starts its own wasm iserv through `dyld.mjs`, so it
        # does not need that wrapper. The proxy also pulls in the target
        # `network` package, which fails to build in this package set.
        enableExternalInterpreter = false;

        # GHC runs the wasm interpreter through `dyld.mjs`, which requires
        # Node. Without Node on PATH, Template Haskell fails with exit status
        # 127.
        buildTools = (args.buildTools or [ ]) ++ [ final.ghc.nodejs ];

        # The wasm interpreter loads dynamic objects. With library profiling
        # enabled, Template Haskell tries to load profiled dynamic objects,
        # which the Cabal build does not produce.
        enableLibraryProfiling = false;

        # GHC's wasm RTS linker requires shared libraries for splices that load
        # dependencies, but generic-builder.nix disables them because wasi32 is
        # `isStatic`.
        enableSharedLibraries = true;

        configureFlags =
          (args.configureFlags or [ ])
          ++ [
            # generic-builder.nix does not select Haddock for cross builds, so
            # Cabal can find a native Haddock built with a different GHC.
            "--with-haddock=${final.ghc.targetPrefix}haddock"
          ]
          ++ [
            # Ideally generic-builder.nix would let an external compiler retain
            # the tools recorded in GHC's settings. Reading the installed
            # settings during Nix evaluation would require IFD, so the bindist
            # adapter exposes wasiSdk explicitly.
            #
            # Cabal uses the last value for repeated `--with-*` options.
            "--with-gcc=${final.ghc.wasiSdk}/bin/wasm32-wasi-clang"
            "--with-ar=${final.ghc.wasiSdk}/bin/llvm-ar"
            "--with-ld=${final.ghc.wasiSdk}/bin/wasm-ld"
          ];
      }
    );
}
