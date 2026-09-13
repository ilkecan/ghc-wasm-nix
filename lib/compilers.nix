# Derived compiler specifications, keyed by the GHC flavours shipped by
# ghc-wasm-meta.
#
# An upstream flavour can have a bindist without having a usable nixpkgs
# bootstrap compiler or compiler configuration. Keep every upstream entry in
# this table; callers must assess nixpkgs usability separately from bindist
# availability.
{ lib }:

{
  versions,
  flavours,
}:

let
  describe = flavour: entry:
    let
      inherit (entry) version;

      majorMinor = lib.versions.majorMinor version;
      short = "${lib.versions.major version}${lib.versions.minor version}";
      numbered = builtins.match "^[0-9]+\\.[0-9]+$" flavour != null;
    in
    entry
    // {
      inherit flavour;

      # The public attribute. Numbered flavours are exposed as `ghcNNN`, while
      # others such as `gmp` retain their flavour name.
      attrName = if numbered then "ghc${lib.replaceStrings [ "." ] [ "" ] flavour}" else flavour;

      # Seed config for the cabal wrapper: head for unnumbered streams, legacy
      # only for 9.6 and 9.8 and TH for other numbered streams.
      cabalConfig =
        if !numbered then "cabal.head.config"
        else if lib.elem flavour [ "9.6" "9.8" ] then "cabal.legacy.config"
        else "cabal.th.config";

      # The native compiler that builds Setup.hs and the host-side tools.
      # Prefer the patch-specific bootstrap attribute derived from `version`.
      # Callers should fall back to the shorter series attribute when the exact
      # attribute is missing from nixpkgs.
      bootstrapAttr = "ghc${short}${if numbered then lib.versions.patch version else ""}";
      fallbackAttr = if numbered then "ghc${short}" else null;

      compilerConfigFile = "configuration-ghc-${majorMinor}.x.nix";
    };
  all = lib.mapAttrs describe versions;
in
{
  inherit all;
  default = all.${flavours.default};

  # The flavours with a bindist for this system. ghc-wasm-meta's package set
  # exposes an attribute for every flavour on every system, but the underlying
  # bindist table is not uniform: 9.6 and 9.8 exist for x86_64-linux only.
  # Forcing one of the others throws from inside ghc-wasm-meta, so they are
  # omitted rather than left to explode.
  availableFor = system:
    lib.filterAttrs (_: entry: lib.elem system entry.systems) all;

  # Every system any flavour ships a bindist for.
  systems = lib.unique (lib.concatMap (entry: entry.systems) (lib.attrValues versions));
}
