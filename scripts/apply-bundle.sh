#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 BUNDLE_ID GCC_VERSION GCC_SOURCE" >&2
  exit 2
fi

bundle=$1
version=$2
source_dir=$3
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"

[[ -f "$source_dir/gcc/ada/exp_ch6.adb" ]] || {
  echo "error: not a GCC source tree: $source_dir" >&2
  exit 1
}

patch_rel=$(python3 "$manifest" bundle "$bundle" "$version" patch)
expected=$(python3 "$manifest" bundle "$bundle" "$version" sha256)
patch_file="$root/$patch_rel"
actual=$(shasum -a 256 "$patch_file" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || {
  echo "error: patch checksum mismatch for $bundle" >&2
  exit 1
}

patch --dry-run --fuzz=0 -p1 -d "$source_dir" -i "$patch_file"
patch --fuzz=0 -p1 -d "$source_dir" -i "$patch_file"
echo "bundle application: PASS $bundle on gcc-$version"
