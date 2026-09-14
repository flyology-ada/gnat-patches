#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"
expected_bundles=$'storage-model-actuals\nprotected-duration-validity'

for version in 16.1.0 16.2.0; do
  python3 "$manifest" validate --patchset 1.1.1 --gcc "$version" >/dev/null
  [[ $(python3 "$manifest" patchset 1.1.1 "$version" source_version) == "$version" ]]
  [[ $(python3 "$manifest" patchset 1.1.1 "$version" gcc_major) == 16 ]]
  [[ $(python3 "$manifest" patchset 1.1.1 "$version" bundles) == "$expected_bundles" ]]
  [[ -z $(python3 "$manifest" patchset 1.1.1 "$version" control_tests) ]]
  [[ -z $(python3 "$manifest" patchset 1.1.1 "$version" staged_bundles) ]]
done

if python3 "$manifest" patchset 1.1.1 16 source_version >/dev/null 2>&1; then
  echo "error: ambiguous GCC 16 target was accepted for patchset 1.1.1" >&2
  exit 1
fi
[[ $(python3 "$manifest" patchset 1.2.0 16 source_version) == 16.2.0 ]]

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/exact-patchset-targets.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
for version in 16.1.0 16.2.0; do
  output="$test_dir/$version"
  "$root/scripts/package-patchset.sh" 1.1.1 "$version" "$output" >/dev/null
  archive="$output/gnat-patchset-1.1.1-gcc-$version.tar.gz"
  [[ -f "$archive" && -f "$archive.sha256" ]]
  tar -xOf "$archive" patchset.toml | grep -Fx "source_version = \"$version\"" >/dev/null
done

legacy_output="$test_dir/legacy-major"
"$root/scripts/package-patchset.sh" 1.2.0 16 "$legacy_output" >/dev/null
[[ -f "$legacy_output/gnat-patchset-1.2.0-gcc-16.tar.gz" ]]
[[ -f "$legacy_output/gnat-patchset-1.2.0-gcc-16.tar.gz.sha256" ]]

echo "exact patchset target selection: PASS"
