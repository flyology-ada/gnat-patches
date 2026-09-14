#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 PATCHSET_VERSION GCC_TARGET GCC_SOURCE" >&2
  exit 2
fi

patchset=$1
target=$2
source_dir=$3
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"

python3 "$manifest" validate --patchset "$patchset" --gcc "$target"
source_version=$(python3 "$manifest" patchset "$patchset" "$target" source_version)
mapfile_command=(python3 "$manifest" patchset "$patchset" "$target" bundles)

while IFS= read -r bundle; do
  [[ -n "$bundle" ]] || continue
  "$root/scripts/apply-bundle.sh" "$bundle" "$source_version" "$source_dir"
done < <("${mapfile_command[@]}")

echo "patchset application: PASS $patchset for GCC $source_version"
