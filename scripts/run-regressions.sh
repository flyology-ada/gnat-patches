#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT PATCHSET_VERSION GCC_MAJOR unpatched|patched" >&2
  exit 2
fi

toolchain=$1
patchset=$2
major=$3
state=$4
[[ "$state" == unpatched || "$state" == patched ]] || {
  echo "error: state must be unpatched or patched" >&2
  exit 2
}
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"
python3 "$manifest" validate --patchset "$patchset" --gcc "$major" >/dev/null
version=$(python3 "$manifest" patchset "$patchset" "$major" source_version)

while IFS= read -r bundle; do
  [[ -n "$bundle" ]] || continue
  runner=$(python3 "$manifest" bundle "$bundle" "$version" runner)
  "$root/$runner" "$toolchain" "$version" "$state"
done < <(
  python3 "$manifest" patchset "$patchset" "$major" bundles
  python3 "$manifest" patchset "$patchset" "$major" control_tests
)

echo "patchset regressions: PASS $patchset gcc-$major ($state)"
