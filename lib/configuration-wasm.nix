# Overrides for using GHC's wasm backend with nixpkgs's Haskell builder.
#
# nixpkgs has configuration files for Windows and GHCJS, but no equivalent for
# wasm.
#
# Upstream status:
# - nixpkgs#558928: enable shared libraries for GHC's wasm interpreter

final: prev: {
  # apply these generic-builder arguments to every package in the set
  mkDerivation =
    args:
    prev.mkDerivation (
      args
      // {

        # GHC's wasm RTS linker requires shared libraries for splices that load
        # dependencies, but generic-builder.nix disables them because wasi32 is
        # `isStatic`.
        enableSharedLibraries = true;

        configureFlags = (args.configureFlags or [ ]) ++ [
          # Ideally generic-builder.nix would let an external compiler retain
          # the tools recorded in GHC's settings. Reading the installed
          # settings during Nix evaluation would require IFD, so the bindist
          # adapter exposes wasiSdk explicitly.
          "--with-ar=${final.ghc.wasiSdk}/bin/llvm-ar"
          "--with-gcc=${final.ghc.wasiSdk}/bin/wasm32-wasi-clang"
          "--with-ld=${final.ghc.wasiSdk}/bin/wasm-ld"

          # Use the strip tool from the WASI SDK paired with the bindist
          # instead of nixpkgs's independently selected target tool.
          "--with-strip=${final.ghc.wasiSdk}/bin/llvm-strip"
        ];
      }
    );
}
