#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT PATCHSET_VERSION GCC_MAJOR unpatched|patched|staged" >&2
  exit 2
fi

toolchain=$1
patchset=$2
major=$3
state=$4
case "$state" in
  unpatched|patched|staged) ;;
  *)
    echo "error: state must be unpatched, patched, or staged" >&2
    exit 2
    ;;
esac
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"
python3 "$manifest" validate --patchset "$patchset" --gcc "$major" >/dev/null
version=$(python3 "$manifest" patchset "$patchset" "$major" source_version)

# A staged toolchain carries the patchset plus the staged bundles, so every
# runner it selects expects patched behavior.
bundle_state=$state
[[ "$state" != staged ]] || bundle_state=patched

while IFS= read -r bundle; do
  [[ -n "$bundle" ]] || continue
  runner=$(python3 "$manifest" bundle "$bundle" "$version" runner)
  "$root/$runner" "$toolchain" "$version" "$bundle_state"
done < <(
  python3 "$manifest" patchset "$patchset" "$major" bundles
  python3 "$manifest" patchset "$patchset" "$major" control_tests
  [[ "$state" != staged ]] ||
    python3 "$manifest" patchset "$patchset" "$major" staged_bundles
)

echo "patchset regressions: PASS $patchset gcc-$major ($state)"
