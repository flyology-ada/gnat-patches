#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 PATCHSET_VERSION GCC_MAJOR GCC_SOURCE" >&2
  exit 2
fi

# Staged bundles are curated and validated but are not part of the published
# patchset. They apply, in the recorded order, on top of a source tree that
# already has the complete patchset applied.
patchset=$1
major=$2
source_dir=$3
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"

python3 "$manifest" validate --patchset "$patchset" --gcc "$major"
source_version=$(python3 "$manifest" patchset "$patchset" "$major" source_version)

while IFS= read -r bundle; do
  [[ -n "$bundle" ]] || continue
  "$root/scripts/apply-bundle.sh" "$bundle" "$source_version" "$source_dir"
done < <(python3 "$manifest" patchset "$patchset" "$major" staged_bundles)

echo "staged application: PASS $patchset for gcc-$major"
