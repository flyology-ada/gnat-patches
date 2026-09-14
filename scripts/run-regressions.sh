#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT PATCHSET_VERSION GCC_TARGET unpatched|patched|staged" >&2
  exit 2
fi

toolchain=$1
patchset=$2
target=$3
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
python3 "$manifest" validate --patchset "$patchset" --gcc "$target" >/dev/null
version=$(python3 "$manifest" patchset "$patchset" "$target" source_version)

# A staged toolchain carries the patchset plus the staged bundles, so every
# runner it selects expects patched behavior.
bundle_state=$state
[[ "$state" != staged ]] || bundle_state=patched

while IFS= read -r bundle; do
  [[ -n "$bundle" ]] || continue
  runner=$(python3 "$manifest" bundle "$bundle" "$version" runner)
  "$root/$runner" "$toolchain" "$version" "$bundle_state"
done < <(
  python3 "$manifest" patchset "$patchset" "$target" bundles
  python3 "$manifest" patchset "$patchset" "$target" control_tests
  [[ "$state" != staged ]] ||
    python3 "$manifest" patchset "$patchset" "$target" staged_bundles
)

echo "patchset regressions: PASS $patchset GCC $version ($state)"
