#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 DESTINATION" >&2
  exit 2
fi

destination=$1
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"
version=2.46.1
url=$(python3 "$manifest" helper "$version" url)
archive=$(python3 "$manifest" helper "$version" archive)
expected=$(python3 "$manifest" helper "$version" sha512)
cache=${GNAT_PATCHES_CACHE:-"$root/.cache"}
path="$cache/sources/$archive"

[[ ! -e "$destination" ]] || {
  echo "error: destination already exists: $destination" >&2
  exit 1
}
mkdir -p "$cache/sources"
if [[ ! -f "$path" ]]; then
  temp="$path.part"
  curl --fail --location --retry 3 --output "$temp" "$url"
  mv "$temp" "$path"
fi
actual=$(shasum -a 512 "$path" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || {
  echo "error: Binutils source checksum mismatch for $archive" >&2
  exit 1
}
mkdir -p "$destination"
tar -xf "$path" --strip-components=1 -C "$destination"
[[ -x "$destination/configure" && -f "$destination/COPYING3" ]] || {
  echo "error: fetched tree is not a Binutils source tree" >&2
  exit 1
}
echo "source fetch: PASS binutils-$version"
