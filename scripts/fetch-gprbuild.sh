#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 PLATFORM DESTINATION" >&2
  exit 2
fi

platform=$1
destination=$2
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=26.0.1

line=$(awk -F '\t' -v v="$version" -v p="$platform" \
  '$1 == v && $2 == p { print; found=1 } END { if (!found) exit 1 }' \
  "$root/ci/gprbuild.tsv") || {
    echo "error: no maintained GPRbuild $version package for $platform" >&2
    exit 1
  }
IFS=$'\t' read -r _ _ url expected <<<"$line"
archive=${url##*/}
cache=${GNAT_PATCHES_CACHE:-"$root/.cache"}
mkdir -p "$cache/gprbuild"
path="$cache/gprbuild/$archive"
if [[ ! -f "$path" ]]; then
  temp="$path.part"
  curl --fail --location --retry 3 --output "$temp" "$url"
  mv "$temp" "$path"
fi
actual=$(shasum -a 256 "$path" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || {
  echo "error: GPRbuild checksum mismatch for $archive" >&2
  exit 1
}
[[ ! -e "$destination" ]] || {
  echo "error: GPRbuild destination already exists: $destination" >&2
  exit 1
}
mkdir -p "$destination"
tar -xzf "$path" -C "$destination"
gprbuild=$(find "$destination" -maxdepth 4 -type f -path '*/bin/gprbuild' -print -quit)
[[ -n "$gprbuild" ]] || {
  echo "error: maintained GPRbuild archive has no gprbuild executable" >&2
  exit 1
}
gprbuild_root=$(dirname "$(dirname "$gprbuild")")
"$gprbuild" --version | grep -F 'GPRBUILD 26.0.0' >/dev/null || {
  echo "error: maintained GPRbuild package has an unexpected binary version" >&2
  exit 1
}
(cd "$gprbuild_root" && pwd)
