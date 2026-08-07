#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 GCC_VERSION DESTINATION" >&2
  exit 2
fi

version=$1
destination=$2
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
[[ "$arch" == aarch64 ]] && arch=arm64

if [[ "$version:$os:$arch" == "13.2.0:linux:arm64" ]]; then
  command -v gnatmake-13 >/dev/null || {
    echo "error: Linux arm64 GCC 13 requires the pinned runner's gnat-13 package" >&2
    exit 1
  }
  dirname "$(dirname "$(command -v gnatmake-13)")"
  exit 0
fi

line=$(awk -F '\t' -v v="$version" -v o="$os" -v a="$arch" \
  '$1 == v && $2 == o && $3 == a { print; found=1 } END { if (!found) exit 1 }' \
  "$root/ci/bootstrap.tsv") || {
    echo "error: no bootstrap compiler for $version/$os/$arch" >&2
    exit 1
  }
IFS=$'\t' read -r _ _ _ release archive expected <<<"$line"
url="https://github.com/alire-project/GNAT-FSF-builds/releases/download/gnat-$release/$archive"
cache=${GNAT_PATCHES_CACHE:-"$root/.cache"}
mkdir -p "$cache/bootstrap"
path="$cache/bootstrap/$archive"
if [[ ! -f "$path" ]]; then
  temp="$path.part"
  curl --fail --location --retry 3 --output "$temp" "$url"
  mv "$temp" "$path"
fi
actual=$(shasum -a 256 "$path" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || {
  echo "error: bootstrap checksum mismatch for $archive" >&2
  exit 1
}
[[ ! -e "$destination" ]] || {
  echo "error: bootstrap destination already exists: $destination" >&2
  exit 1
}
mkdir -p "$destination"
tar -xzf "$path" -C "$destination"
gnatmake=$(find "$destination" -maxdepth 4 -type f -path '*/bin/gnatmake' -print -quit)
[[ -n "$gnatmake" ]] || { echo "error: bootstrap archive has no gnatmake" >&2; exit 1; }
bootstrap_root=$(dirname "$(dirname "$gnatmake")")
(cd "$bootstrap_root" && pwd)
