{
  description = "A small nixpkgs consumer for GHC's wasm backend";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    ghc-wasm-meta = {
      url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ghc-wasm-meta,
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      mkGhc =
        {
          pkgs,
        }:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          metaPackages = ghc-wasm-meta.packages.${system};
        in
        import ./lib/ghc-bindist.nix { inherit (pkgs) lib; } {
          ghc = metaPackages."wasm32-wasi-ghc-9_14";
          inherit (metaPackages) nodejs;
          wasiSdk = metaPackages.wasi-sdk;
          version = "9.14.1.20260731";
        };
    in
    {
      lib = { inherit mkGhc; };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          ghc = mkGhc { inherit pkgs; };
        in
        {
          inherit ghc;
          default = ghc;
        }
      );
    };
}
