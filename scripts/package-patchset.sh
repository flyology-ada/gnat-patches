#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 PATCHSET_VERSION GCC_TARGET OUTPUT_DIR" >&2
  exit 2
fi

patchset=$1
target=$2
output=$3
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"
python3 "$manifest" validate --patchset "$patchset" --gcc "$target"
[[ ! -e "$output" ]] || { echo "error: output already exists: $output" >&2; exit 1; }
mkdir -p "$output/stage/patches" "$output/stage/tests" "$output/stage/manifests/bundles"

source_version=$(python3 "$manifest" patchset "$patchset" "$target" source_version)
patchset_manifest=$(python3 "$manifest" patchset "$patchset" "$target" path)
cp "$root/$patchset_manifest" "$output/stage/patchset.toml"
cp "$root/sources/gcc-$source_version.toml" "$output/stage/source.toml"
cp "$root/README.md" "$output/stage/README.md"
cp "$root/LICENSE" "$output/stage/LICENSE"
: >"$output/stage/series"
while IFS= read -r bundle; do
  [[ -n "$bundle" ]] || continue
  patch_rel=$(python3 "$manifest" bundle "$bundle" "$source_version" patch)
  variant=$(python3 "$manifest" bundle "$bundle" "$source_version" variant)
  cp "$root/$patch_rel" "$output/stage/patches/$bundle-$variant.patch"
  cp "$root/bundles/$bundle/manifest.toml" "$output/stage/manifests/bundles/$bundle.toml"
  cp "$root/bundles/$bundle/tests/"* "$output/stage/tests/"
  echo "patches/$bundle-$variant.patch" >>"$output/stage/series"
done < <(python3 "$manifest" patchset "$patchset" "$target" bundles)

while IFS= read -r bundle; do
  [[ -n "$bundle" ]] || continue
  cp "$root/bundles/$bundle/manifest.toml" "$output/stage/manifests/bundles/$bundle.toml"
  cp "$root/bundles/$bundle/tests/"* "$output/stage/tests/"
done < <(python3 "$manifest" patchset "$patchset" "$target" control_tests)

(
  cd "$output/stage"
  find . -type f ! -name SHA256SUMS -print | LC_ALL=C sort | xargs shasum -a 256 >SHA256SUMS
)
archive_target=$target
[[ "$target" != *.* ]] || archive_target=$source_version
archive="gnat-patchset-$patchset-gcc-$archive_target.tar.gz"
python3 "$root/scripts/deterministic-archive.py" "$output/stage" "$output/$archive"
shasum -a 256 "$output/$archive" >"$output/$archive.sha256"
echo "$output/$archive"
