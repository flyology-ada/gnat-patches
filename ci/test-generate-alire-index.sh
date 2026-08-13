#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/alire-index-generator-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

for platform in linux-x86_64 linux-aarch64 macos-aarch64; do
  archive="gnat-flyology-native-gcc-16.2.0-patchset-1.1.0-$platform.tar.gz"
  printf 'fixture for %s\n' "$platform" >"$test_dir/$archive"
  digest=$(shasum -a 256 "$test_dir/$archive" | cut -d ' ' -f 1)
  printf '%s  %s\n' "$digest" "$archive" >"$test_dir/$archive.sha256"
done

"$root/scripts/generate-alire-index.py" \
  1.1.0 16 "$test_dir" "$test_dir/output" >/dev/null
manifest="$test_dir/output/index/gn/gnat_flyology_native/gnat_flyology_native-16.2.0-patchset.1.1.0.toml"
[[ -f "$manifest" ]]
[[ $(grep -Fc \
  '/releases/download/patchset-1.1.0-gcc-16.2.0/' "$manifest") -eq 3 ]]
if grep -F '/releases/download/patchset-1.1.0-gcc-16/' "$manifest"; then
  echo "error: generated manifest uses a major-only release tag" >&2
  exit 1
fi

echo "Alire index release URLs: PASS"
