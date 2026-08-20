#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 PATCHSET_VERSION GCC_MAJOR PRISTINE_GCC_SOURCE" >&2
  exit 2
fi

# Prove each bundle's declared standalone_patch against pristine upstream
# source. A standalone patch must apply there with zero fuzz; a bundle that
# declares otherwise must not, because it belongs to the patchset's ordered
# series. The source tree is only ever dry-run against, never modified.
patchset=$1
major=$2
source_dir=$3
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"

[[ -f "$source_dir/gcc/ada/exp_ch6.adb" ]] || {
  echo "error: not a GCC source tree: $source_dir" >&2
  exit 1
}

python3 "$manifest" validate --patchset "$patchset" --gcc "$major"
version=$(python3 "$manifest" patchset "$patchset" "$major" source_version)
failures=0

while IFS= read -r bundle; do
  [[ -n "$bundle" ]] || continue
  declared=$(python3 "$manifest" bundle-field "$bundle" standalone_patch)
  patch_file=$(python3 "$manifest" bundle "$bundle" "$version" patch)
  if patch --dry-run --fuzz=0 -p1 --batch --forward \
      -d "$source_dir" -i "$root/$patch_file" >/dev/null 2>&1; then
    observed=true
  else
    observed=false
  fi
  if [[ "$declared" != "$observed" ]]; then
    echo "error: $bundle declares standalone_patch=$declared but applies to pristine source: $observed" >&2
    failures=$((failures + 1))
  else
    echo "standalone_patch $bundle: $observed"
  fi
done < <(
  # Control tests have no patch variant for a release they do not affect.
  python3 "$manifest" patchset "$patchset" "$major" bundles
  python3 "$manifest" patchset "$patchset" "$major" staged_bundles
)

[[ $failures -eq 0 ]] || exit 1
echo "standalone patch claims: PASS $patchset for gcc-$major"
