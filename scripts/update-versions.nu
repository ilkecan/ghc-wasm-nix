#!/usr/bin/env nu

# Extracts exact GHC versions from ghc-wasm-meta's ghcup metadata.
#
# The exact version string is otherwise only discoverable by unpacking a
# bindist. autogen.json is authoritative for the artifacts and additionally
# includes the moving native and unreg variants, but records no compiler
# versions.

# Maps ghcup architecture and OS keys to Nix system identifiers.
const SYSTEMS = {
  A_64_Linux_UnknownLinux: "x86_64-linux"
  A_64_Linux_Alpine: "x86_64-linux"
  A_64_Darwin: "x86_64-darwin"
  A_ARM64_Linux_UnknownLinux: "aarch64-linux"
  A_ARM64_Linux_Alpine: "aarch64-linux"
  A_ARM64_Darwin: "aarch64-darwin"
}

def main [
  src: string  # a ghc-wasm-meta source tree
] {
  let metadata_files = (glob $"($src)/ghcup-wasm-*.yaml")
  let metadata_count = ($metadata_files | length)

  if $metadata_count != 1 {
    error make {
      msg: $"expected exactly one ghcup-wasm metadata file in ($src), found ($metadata_count)"
    }
  }

  let metadata = ($metadata_files | first)

  open $metadata
  | get ghcupDownloads.GHC
  | transpose key entry
  | each { describe_compiler $in }
  | reduce --fold {} { |it, acc|
      $acc | insert $it.flavour {
        version: $it.version
        systems: $it.systems
      }
    }
  | sort_by_flavour
  | to json
}

def describe_compiler [it: record] {
  let downloads = (
    $it.entry.viArch
    | transpose arch oses
    | each { |a| $a.oses | transpose os spec | each { |o| {
        system: (nix_system $a.arch $o.os)
        uri: $o.spec.unknown_versioning.dlUri
      } } }
    | flatten
  )
  let flavours = ($downloads | get uri | each { bindist_flavour $in } | uniq)
  let flavour_count = ($flavours | length)

  if $flavour_count != 1 {
    error make {
      msg: $"expected one bindist flavour for ($it.key), found ($flavour_count): ($flavours | str join ', ')"
    }
  }

  {
    version: ($it.key | str replace "wasm32-wasi-" "")
    flavour: ($flavours | first)
    systems: ($downloads | get system | uniq | sort)
  }
}

def nix_system [arch: string, os: string] {
  let key = $"($arch)_($os)"
  let system = ($SYSTEMS | get --optional $key)

  if $system == null {
    error make { msg: $"no Nix system mapping for ghcup platform ($arch)/($os)" }
  }

  $system
}

def bindist_flavour [uri: string] {
  let name = ($uri | path basename)
  let matches = (
    $name
    | parse --regex '(?:^|-)(?<flavour>gmp|native|unreg|\d+\.\d+)\.tar(?:\..+)?$'
  )

  if ($matches | length) != 1 {
    error make { msg: $"cannot extract a recognized bindist flavour from ($name)" }
  }

  $matches | first | get flavour
}

def sort_by_flavour []: record -> record {
  transpose flavour entry
  | sort-by --natural --reverse flavour
  | reduce --fold {} { |it, acc| $acc | insert $it.flavour $it.entry }
}
