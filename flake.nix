{
  description = "A small nixpkgs consumer for GHC's wasm backend";

  inputs = {
    nixpkgs.url = "nixpkgs-unstable";

    flake-parts = {
      url = "flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    ghc-wasm-meta = {
      url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      flake-parts,
      ghc-wasm-meta,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      compilers = import ./lib/compilers.nix { inherit (nixpkgs) lib; } {
        versions = builtins.fromJSON (builtins.readFile ./versions.json);
        flavours = import ./flavours.nix;
      };

      # Reinstantiates upstream `pkgs/wasm32-wasi-ghc.nix` against the caller
      # `pkgs`.
      mkGhc =
        {
          pkgs,
          flavour ? compilers.default.flavour,
        }:
        let
          spec = compilers.all.${flavour};
          # Mirrors upstream `wasm32-wasi-ghc.nix`'s `nodejs = nodejs_latest;`
          # binding.
          nodejs = pkgs.nodejs_latest;
          ghc = pkgs.callPackage "${ghc-wasm-meta}/pkgs/wasm32-wasi-ghc.nix" {
            inherit flavour;
            nodejs_latest = nodejs;
          };
          # Internal SDK in `wasm32-wasi-ghc.nix` is not addressable and
          # `ghc-wasm-meta.packages.wasi-sdk` uses the upstream `pkgs`.
          wasiSdk = pkgs.callPackage "${ghc-wasm-meta}/pkgs/wasi-sdk.nix" { };
        in
        import ./lib/ghc-bindist.nix { inherit (pkgs) lib; } {
          inherit ghc nodejs wasiSdk;
          inherit (spec) version;
        };

      # Builds a `wasm32-wasi-cabal` wrapper around the given `cabal-install`,
      # seeded from the upstream config for `flavour`.
      mkCabalWrapper =
        {
          pkgs,
          cabal-install ? pkgs.cabal-install,
          flavour ? compilers.default.flavour,
        }:
        let
          spec = compilers.all.${flavour};
        in
        pkgs.callPackage ./lib/wrap-cabal.nix {
          inherit flavour cabal-install;
          configFile = "${ghc-wasm-meta}/${spec.cabalConfig}";
        };

      mkCompilerPackage = pkgs: flavour: spec:
        lib.nameValuePair spec.attrName (mkGhc { inherit pkgs flavour; });

      mkCompilerPackages = pkgs:
        lib.mapAttrs' (mkCompilerPackage pkgs) (compilers.availableFor pkgs.stdenv.hostPlatform.system);

      mkCabalPackage = pkgs: flavour: spec:
        lib.nameValuePair spec.attrName (mkCabalWrapper { inherit pkgs flavour; });

      mkCabalPackages = pkgs:
        lib.mapAttrs' (mkCabalPackage pkgs) (compilers.availableFor pkgs.stdenv.hostPlatform.system);

      mkPackageSetBase =
        {
          flavour,
          packageSetConfig,
          pkgs,
          stdenv,
          ghc,
        }:
        let
          spec = compilers.all.${flavour};
          buildHaskellPackages =
            if pkgs.haskell.packages ? ${spec.bootstrapAttr} then
              pkgs.haskell.packages.${spec.bootstrapAttr}
            else if spec.fallbackAttr != null then
              if pkgs.haskell.packages ? ${spec.fallbackAttr} then
                lib.warn ''
                  ghc-wasm ${flavour}: nixpkgs does not provide bootstrap ${spec.bootstrapAttr} for bindist ${spec.version}; falling back to haskell.packages.${spec.fallbackAttr}
                ''
                pkgs.haskell.packages.${spec.fallbackAttr}
              else
                throw ''
                  ghc-wasm ${flavour}: neither bootstrap ${spec.bootstrapAttr} nor fallback ${spec.fallbackAttr} exists in nixpkgs
                ''
            else
              throw ''
                ghc-wasm ${flavour}: bootstrap ${spec.bootstrapAttr} does not exist in nixpkgs and this flavour has no fallback bootstrap
              '';
        in
        import ./lib/package-set.nix { nixpkgsSrc = pkgs.path; } {
          inherit ghc packageSetConfig stdenv buildHaskellPackages;
          compilerConfigFile = spec.compilerConfigFile;
          wasmPkgs = pkgs.pkgsCross.wasi32;
        };

      mkRawPackageSet =
        {
          pkgs,
          flavour ? compilers.default.flavour,
          packageSetConfig ? (_final: _prev: { }),
          ghc ? mkGhc { inherit flavour pkgs; },
        }:
        mkPackageSetBase {
          inherit flavour packageSetConfig pkgs ghc;
          stdenv = pkgs.pkgsCross.wasi32.stdenv;
        };

      mkPackageSet =
        {
          pkgs,
          flavour ? compilers.default.flavour,
          packageSetConfig ? (_final: _prev: { }),
          ghc ? mkGhc { inherit flavour pkgs; },
        }:
        let
          inherit (pkgs) lib;
          wasmPkgs = pkgs.pkgsCross.wasi32;
        in
        mkPackageSetBase {
          inherit flavour pkgs ghc;
          packageSetConfig = lib.composeManyExtensions [
            (import ./lib/configuration-wasm.nix)
            packageSetConfig
          ];
          # remove the static adapter's Cabal flags so configuration-wasm.nix
          # can enable shared libraries
          stdenv = wasmPkgs.stdenvAdapters.overrideMkDerivationArgs (oldAttrs: {
            configureFlags = lib.subtractLists [
              "--enable-static"
              "--disable-shared"
            ] (oldAttrs.configureFlags or [ ]);
          }) wasmPkgs.stdenv;
        };

      # Deliberately unfiltered by nixpkgs support; unsupported flavours fail
      # lazily on access.
      mkFlavourPackageSets = pkgs:
        let
          availableCompilers = compilers.availableFor pkgs.stdenv.hostPlatform.system;
        in
        compilerSet:
        lib.mapAttrs'
          (flavour: spec:
            lib.nameValuePair spec.attrName (
              mkPackageSet {
                inherit flavour pkgs;
                ghc = compilerSet.${spec.attrName};
              }
            )
          )
          availableCompilers;
    in
    flake-parts.lib.mkFlake { inherit inputs; } ({ config, ... }: {
      # Build the flake on every system exposed by nixpkgs for which
      # ghc-wasm-meta publishes at least one compiler bindist.
      systems = lib.intersectLists compilers.systems lib.systems.flakeExposed;

      flake = {
        lib = { inherit mkCabalWrapper mkGhc mkPackageSet; };

        overlays.default = final: _prev:
          {
            haskellWasm.cabal = mkCabalPackages final;
            haskellWasm.lib = config.flake.lib;
            haskellWasmCabal = final.haskellWasm.cabal.${compilers.default.attrName};

            # Mirrors `pkgs.haskell.compiler.*` and `pkgs.haskell.packages.*`.
            haskellWasm.compiler = mkCompilerPackages final;
            haskellWasm.packages = mkFlavourPackageSets final final.haskellWasm.compiler;
            haskellWasmPackages = final.haskellWasm.packages.${compilers.default.attrName};
          };
      };

      perSystem =
        { pkgs, system, config, ... }:
        let
          haskellPackages = mkPackageSet { inherit pkgs; };
          runtimeFixture = haskellPackages.callPackage ./checks/runtime { };
          runtimeExpected = pkgs.writeText "runtime-expected" ''
            wasm runtime ran
          '';
          mkBindistMetadataCheck = flavour: spec:
            let
              inherit (spec) attrName;
              compiler = config.packages.${spec.attrName};

              # Force drvPath to verify that versions.json advertises an
              # instantiable bindist for this flavour and system. stringLength
              # discards the string context, so the bindist cannot become a
              # build dependency.
              bindistOk = lib.tryEval (lib.stringLength compiler.drvPath);
            in
            {
              name = "bindist-metadata-${attrName}";
              value =
                if !bindistOk.success then
                  throw "bindist-metadata-${attrName}: could not instantiate compiler ${attrName} for ${system} (flavour ${flavour})"
                else
                  pkgs.writeText "bindist-metadata-${attrName}-check" ''
                    flavour ${flavour}
                    version ${spec.version}
                    system ${system}
                  '';
            };
        in
        {
          apps = {
            update-versions = {
              program = lib.getExe (
                pkgs.writeShellApplication {
                  name = "update-versions";
                  runtimeInputs = with pkgs; [ nushell ];
                  text = ''exec ${./scripts/update-versions.nu} ${ghc-wasm-meta} > "''${1:-versions.json}"'';
                }
              );
              meta.description = "Update compiler metadata from ghc-wasm-meta's ghcup YAML";
            };
          };

          checks = lib.mapAttrs' mkBindistMetadataCheck (compilers.availableFor system) // {
            bindist-toolchain = haskellPackages.callPackage ./checks/bindist-toolchain { };

            cabal-routing = pkgs.callPackage ./checks/cabal-routing {
              cabalWrapper = config.packages.cabal;
              ghc = config.packages.ghc;
              expectedConfig = "${ghc-wasm-meta}/${compilers.default.cabalConfig}";
            };

            haddock = haskellPackages.callPackage ./checks/haddock { };

            runtime-node = pkgs.testers.testEqualContents {
              assertion = "Node runs the wasm fixture";
              actual = pkgs.runCommand "runtime-node-output" { } ''
                ${lib.getExe pkgs.nodejs} ${./checks/runtime/run-node.mjs} \
                  ${runtimeFixture}/bin/runtime-fixture.wasm > "$out"
              '';
              expected = runtimeExpected;
            };

            runtime-wasmedge = pkgs.testers.testEqualContents {
              assertion = "WasmEdge runs the wasm fixture";
              actual = pkgs.runCommand "runtime-wasmedge-output" { } ''
                ${lib.getExe pkgs.wasmedge} run \
                  ${runtimeFixture}/bin/runtime-fixture.wasm > "$out"
              '';
              expected = runtimeExpected;
            };

            runtime-wasmer = pkgs.testers.testEqualContents {
              assertion = "Wasmer runs the wasm fixture";
              actual = pkgs.runCommand "runtime-wasmer-output" { } ''
                ${lib.getExe pkgs.wasmer} run \
                  ${runtimeFixture}/bin/runtime-fixture.wasm > "$out"
              '';
              expected = runtimeExpected;
            };

            runtime-wasmtime = pkgs.testers.testEqualContents {
              assertion = "Wasmtime runs the wasm fixture";
              actual = pkgs.runCommand "runtime-wasmtime-output" { } ''
                ${lib.getExe pkgs.wasmtime} run -C cache=n \
                  ${runtimeFixture}/bin/runtime-fixture.wasm > "$out"
              '';
              expected = runtimeExpected;
            };

            shared-libraries = haskellPackages.callPackage ./checks/shared-libraries { };
            template-haskell = haskellPackages.callPackage ./checks/template-haskell { };

            wasm-opt = pkgs.runCommand "wasm-opt-check" { } ''
              input="${runtimeFixture}/bin/runtime-fixture.wasm"
              ${pkgs.binaryen}/bin/wasm-opt -Oz "$input" -o optimized.wasm
              test "$(stat -c %s optimized.wasm)" -lt "$(stat -c %s "$input")"
              ${pkgs.wasm-tools}/bin/wasm-tools validate optimized.wasm
              cp optimized.wasm "$out"
            '';
          };

          packages = {
            cabal = config.packages."cabal-${compilers.default.attrName}";
            default = config.packages.ghc;
            ghc = config.packages.${compilers.default.attrName};

            shared-libraries-repro = import ./repros/shared-libraries.nix {
              inherit pkgs;
              mkPackageSet = mkRawPackageSet;
            };
          }
          // mkCompilerPackages pkgs
          // lib.mapAttrs' (name: cabal: lib.nameValuePair "cabal-${name}" cabal) (mkCabalPackages pkgs)
          ;

          legacyPackages = mkFlavourPackageSets pkgs config.packages;
        };
    });
}
