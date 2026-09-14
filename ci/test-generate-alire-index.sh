#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/alire-index-generator-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

for version in 13.2.0 14.2.0 15.3.0 16.1.0 16.2.0; do
  toolchains="$test_dir/toolchains-$version"
  mkdir -p "$toolchains"
  for platform in linux-x86_64 linux-aarch64 macos-aarch64; do
    archive="gnat-flyology-native-gcc-$version-patchset-1.1.1-$platform.tar.gz"
    printf 'fixture for %s on GCC %s\n' "$platform" "$version" \
      >"$toolchains/$archive"
    digest=$(shasum -a 256 "$toolchains/$archive" | cut -d ' ' -f 1)
    printf '%s  %s\n' "$digest" "$archive" >"$toolchains/$archive.sha256"
  done

  output="$test_dir/output-$version"
  "$root/scripts/generate-alire-index.py" \
    1.1.1 "$version" "$toolchains" "$output" >/dev/null
  manifest="$output/index/gn/gnat_flyology_native/gnat_flyology_native-$version-patchset.1.1.1.toml"
  [[ -f "$manifest" ]]
  [[ $(grep -Fc \
    "/releases/download/patchset-1.1.1-gcc-$version/" "$manifest") -eq 3 ]]
done

echo "Alire index generator exact targets: PASS"
