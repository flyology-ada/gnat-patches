#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 GCC_VERSION DESTINATION" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage
version=$1
destination=$2
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$root/scripts/manifest.py"

if [[ -e "$destination" ]]; then
  echo "error: destination already exists: $destination" >&2
  exit 1
fi

flavor=${GNAT_PATCHES_SOURCE_FLAVOR:-}
if [[ -z "$flavor" ]]; then
  case "$(uname -s):$(uname -m)" in
    Linux:*) flavor=linux ;;
    Darwin:arm64|Darwin:aarch64) flavor=darwin_arm64 ;;
    Darwin:*) echo "error: only macOS arm64 is supported" >&2; exit 1 ;;
    *) echo "error: unsupported host" >&2; exit 1 ;;
  esac
fi

if [[ "$flavor" == linux ]]; then
  url=$(python3 "$manifest" source "$version" linux.url)
  archive=$(python3 "$manifest" source "$version" linux.archive)
  expected=$(python3 "$manifest" source "$version" linux.sha512)
  cache=${GNAT_PATCHES_CACHE:-"$root/.cache"}
  mkdir -p "$cache/sources"
  path="$cache/sources/$archive"
  if [[ ! -f "$path" ]]; then
    temp="$path.part"
    curl --fail --location --retry 3 --output "$temp" "$url"
    mv "$temp" "$path"
  fi
  actual=$(shasum -a 512 "$path" | awk '{print $1}')
  if [[ "$actual" != "$expected" ]]; then
    echo "error: source checksum mismatch for $archive" >&2
    exit 1
  fi
  mkdir -p "$destination"
  tar -xf "$path" --strip-components=1 -C "$destination"
elif [[ "$flavor" == darwin_arm64 ]]; then
  repository=$(python3 "$manifest" source "$version" darwin_arm64.repository)
  tag=$(python3 "$manifest" source "$version" darwin_arm64.tag)
  commit=$(python3 "$manifest" source "$version" darwin_arm64.commit)
  tree=$(python3 "$manifest" source "$version" darwin_arm64.tree)
  cache=${GNAT_PATCHES_CACHE:-"$root/.cache"}
  cache_repo="$cache/sources/darwin-$version.git"
  if [[ ! -d "$cache_repo" ]]; then
    mkdir -p "$cache/sources"
    git init --bare "$cache_repo"
  fi
  if ! git --git-dir "$cache_repo" cat-file -e "$commit^{commit}" 2>/dev/null; then
    git --git-dir "$cache_repo" fetch --depth=1 "$repository" \
      "refs/tags/$tag:refs/tags/$tag"
  fi
  git clone --no-checkout "$cache_repo" "$destination"
  git -C "$destination" checkout --detach "$commit"
  [[ $(git -C "$destination" rev-parse HEAD) == "$commit" ]] || {
    echo "error: Darwin source commit mismatch" >&2; exit 1;
  }
  [[ $(git -C "$destination" rev-parse 'HEAD^{tree}') == "$tree" ]] || {
    echo "error: Darwin source tree mismatch" >&2; exit 1;
  }
else
  echo "error: unknown source flavor: $flavor" >&2
  exit 1
fi

[[ -f "$destination/gcc/ada/exp_ch6.adb" ]] || {
  echo "error: fetched tree is not a GCC/GNAT source tree" >&2
  exit 1
}
echo "source fetch: PASS gcc-$version ($flavor)"
