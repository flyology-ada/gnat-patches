#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"
expected_versions=$'13.2.0\n14.2.0\n15.3.0\n16.1.0\n16.2.0'

actual_versions=$(
  awk -F '"' '/^source_version = / { print $2 }' \
    "$root"/patchsets/1.1.1/gcc-*.toml | LC_ALL=C sort
)
if [[ $actual_versions != "$expected_versions" ]]; then
  echo "error: patchset 1.1.1 targets do not match patchset 1.1.0" >&2
  diff -u <(printf '%s\n' "$expected_versions") \
    <(printf '%s\n' "$actual_versions") >&2 || true
  exit 1
fi

while read -r version major; do
  python3 "$manifest" validate --patchset 1.1.1 --gcc "$version" >/dev/null
  [[ $(python3 "$manifest" patchset 1.1.1 "$version" source_version) == "$version" ]]
  [[ $(python3 "$manifest" patchset 1.1.1 "$version" gcc_major) == "$major" ]]
  for field in bundles control_tests staged_bundles; do
    [[ $(python3 "$manifest" patchset 1.1.1 "$version" "$field") == \
      "$(python3 "$manifest" patchset 1.1.0 "$major" "$field")" ]]
  done
  if [[ $major != 16 ]]; then
    [[ $(python3 "$manifest" patchset 1.1.1 "$major" source_version) == "$version" ]]
  fi
done <<'EOF'
13.2.0 13
14.2.0 14
15.3.0 15
16.1.0 16
16.2.0 16
EOF

if python3 "$manifest" patchset 1.1.1 16 source_version >/dev/null 2>&1; then
  echo "error: ambiguous GCC 16 target was accepted for patchset 1.1.1" >&2
  exit 1
fi
[[ $(python3 "$manifest" patchset 1.2.0 16 source_version) == 16.2.0 ]]

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/exact-patchset-targets.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
for version in 13.2.0 14.2.0 15.3.0 16.1.0 16.2.0; do
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
