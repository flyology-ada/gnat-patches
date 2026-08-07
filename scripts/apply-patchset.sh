#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 PATCHSET_VERSION GCC_MAJOR GCC_SOURCE" >&2
  exit 2
fi

patchset=$1
major=$2
source_dir=$3
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"

python3 "$manifest" validate --patchset "$patchset" --gcc "$major"
source_version=$(python3 "$manifest" patchset "$patchset" "$major" source_version)
mapfile_command=(python3 "$manifest" patchset "$patchset" "$major" bundles)

while IFS= read -r bundle; do
  [[ -n "$bundle" ]] || continue
  "$root/scripts/apply-bundle.sh" "$bundle" "$source_version" "$source_dir"
done < <("${mapfile_command[@]}")

echo "patchset application: PASS $patchset for gcc-$major"
