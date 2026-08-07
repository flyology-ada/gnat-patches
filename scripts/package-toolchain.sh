#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 7 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT GCC_SOURCE BINUTILS_ROOT_OR_DASH PATCHSET_VERSION GCC_MAJOR PLATFORM OUTPUT_DIR" >&2
  exit 2
fi

toolchain=$(cd "$1" && pwd)
source_dir=$(cd "$2" && pwd)
binutils_arg=$3
patchset=$4
major=$5
platform=$6
output=$7
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

case "$platform" in
  linux-x86_64|linux-aarch64|macos-aarch64) ;;
  *) echo "error: unsupported Alire toolchain platform: $platform" >&2; exit 2 ;;
esac

if [[ "$platform" == linux-* ]]; then
  [[ "$binutils_arg" != - ]] || {
    echo "error: Linux toolchains require source-built Binutils helpers" >&2
    exit 1
  }
  binutils=$(cd "$binutils_arg" && pwd)
  [[ -x "$binutils/bin/as" && -x "$binutils/bin/ld" ]] || {
    echo "error: Binutils helper root lacks as or ld" >&2
    exit 1
  }
  "$binutils/bin/as" --version | grep -F '2.46.1' >/dev/null || {
    echo "error: Binutils helper is not version 2.46.1" >&2
    exit 1
  }
  [[ -f "$binutils/share/gnat-patches-binutils/SOURCE_PROVENANCE.txt" ]] || {
    echo "error: Binutils helper lacks source provenance" >&2
    exit 1
  }
  cp -a "$binutils/." "$toolchain/"
elif [[ "$binutils_arg" != - ]]; then
  echo "error: macOS toolchains must use the system Xcode assembler and linker" >&2
  exit 1
fi

python3 "$root/scripts/manifest.py" validate --patchset "$patchset" --gcc "$major" >/dev/null
source_version=$(python3 "$root/scripts/manifest.py" patchset "$patchset" "$major" source_version)
reported=$("$toolchain/bin/gcc" -dumpfullversion)
[[ "$reported" == "$source_version" ]] || {
  echo "error: toolchain reports GCC $reported, expected $source_version" >&2
  exit 1
}
[[ -x "$toolchain/bin/gnatmake" ]] || {
  echo "error: toolchain has no executable gnatmake" >&2
  exit 1
}
[[ -f "$source_dir/COPYING3" && -f "$source_dir/COPYING.RUNTIME" ]] || {
  echo "error: GCC source tree lacks required license notices" >&2
  exit 1
}

bundle_linux_libraries() {
  local destination="$toolchain/lib64"
  local candidate dependency name
  mkdir -p "$destination"
  while IFS= read -r -d '' candidate; do
    while IFS= read -r dependency; do
      name=$(basename "$dependency")
      case "$name" in
        libgmp.so.*|libmpfr.so.*|libmpc.so.*|libisl.so.*|libzstd.so.*|libz.so.*)
          [[ -e "$destination/$name" ]] || cp -L "$dependency" "$destination/$name"
          ;;
      esac
    done < <(ldd "$candidate" 2>/dev/null | awk '$2 == "=>" && $3 ~ /^\// { print $3 }' || true)
  done < <(find "$toolchain/bin" "$toolchain/libexec" -type f -perm -111 -print0)
}

bundle_macos_libraries() {
  local prefixes=()
  local formula prefix candidate dependency name copied loader_lib replacement description
  for formula in gmp mpfr libmpc; do
    prefix=$(brew --prefix "$formula")
    prefixes+=("$prefix")
    prefixes+=("$(cd "$prefix" && pwd -P)")
  done
  mkdir -p "$toolchain/lib"
  local dependencies=()
  while IFS= read -r -d '' candidate; do
    file -b "$candidate" | grep -q 'Mach-O' || continue
    while IFS= read -r dependency; do
      for prefix in "${prefixes[@]}"; do
        if [[ "$dependency" == "$prefix/"* ]]; then
          dependencies+=("$dependency")
          name=$(basename "$dependency")
          copied="$toolchain/lib/$name"
          [[ -e "$copied" ]] || cp -L "$dependency" "$copied"
          break
        fi
      done
    done < <(otool -L "$candidate" | awk 'NR > 1 { print $1 }')
  done < <(find "$toolchain/bin" "$toolchain/libexec" -type f \
    ! -path '*.dSYM/*' -perm -111 -print0)

  # Follow the small numerical-library dependency chain (MPC -> MPFR -> GMP).
  for _ in 1 2 3; do
    for copied in "$toolchain/lib/"*.dylib; do
      [[ -e "$copied" ]] || continue
      while IFS= read -r dependency; do
        for prefix in "${prefixes[@]}"; do
          if [[ "$dependency" == "$prefix/"* ]]; then
            dependencies+=("$dependency")
            name=$(basename "$dependency")
            [[ -e "$toolchain/lib/$name" ]] || \
              cp -L "$dependency" "$toolchain/lib/$name"
            break
          fi
        done
      done < <(otool -L "$copied" | awk 'NR > 1 { print $1 }')
    done
  done

  while IFS= read -r -d '' candidate; do
    description=$(file -b "$candidate")
    case "$description" in
      *Mach-O*executable*|*Mach-O*dynamically\ linked\ shared\ library*|*Mach-O*bundle*) ;;
      *) continue ;;
    esac
    loader_lib=$(python3 -c \
      'import os, sys; print(os.path.relpath(sys.argv[2], sys.argv[1]))' \
      "$(dirname "$candidate")" "$toolchain/lib")
    for dependency in "${dependencies[@]}"; do
      name=$(basename "$dependency")
      if [[ "$loader_lib" == . ]]; then
        replacement="@loader_path/$name"
      else
        replacement="@loader_path/$loader_lib/$name"
      fi
      install_name_tool -change "$dependency" "$replacement" "$candidate"
    done
  done < <(find "$toolchain/bin" "$toolchain/libexec" "$toolchain/lib" \
    -type f ! -path '*.dSYM/*' -print0)
  for copied in "$toolchain/lib/"*.dylib; do
    [[ -e "$copied" ]] || continue
    install_name_tool -id "$(basename "$copied")" "$copied"
  done
}

strip_toolchain_binaries() {
  local candidate description
  while IFS= read -r -d '' candidate; do
    if [[ "$platform" == linux-* ]]; then
      if "$toolchain/bin/readelf" -h "$candidate" >/dev/null 2>&1; then
        [[ "$candidate" == "$toolchain/bin/strip" ]] || \
          "$toolchain/bin/strip" --strip-debug "$candidate"
      fi
    else
      description=$(file -b "$candidate")
      [[ "$description" != *Mach-O* ]] || strip -S "$candidate"
    fi
  done < <(find "$toolchain/bin" "$toolchain/libexec" "$toolchain/lib" \
    "$toolchain/lib64" -type f ! -path '*.dSYM/*' -perm -111 -print0 2>/dev/null)
}

sign_macos_binaries() {
  local candidate description
  while IFS= read -r -d '' candidate; do
    description=$(file -b "$candidate")
    case "$description" in
      *Mach-O*executable*|*Mach-O*dynamically\ linked\ shared\ library*|*Mach-O*bundle*)
        codesign --force --sign - "$candidate"
        codesign --verify --strict "$candidate"
        ;;
    esac
  done < <(find "$toolchain/bin" "$toolchain/libexec" "$toolchain/lib" \
    "$toolchain/lib64" -type f ! -path '*.dSYM/*' -print0 2>/dev/null)
}

case "$platform" in
  linux-*) bundle_linux_libraries ;;
  macos-aarch64) bundle_macos_libraries ;;
esac
strip_toolchain_binaries
[[ "$platform" != macos-aarch64 ]] || sign_macos_binaries

if [[ "$platform" == linux-* ]]; then
  for library in gmp mpfr mpc; do
    compgen -G "$toolchain/lib64/lib$library.so.*" >/dev/null || {
      echo "error: packaged toolchain lacks lib$library" >&2
      exit 1
    }
  done
else
  for library in gmp mpfr mpc; do
    compgen -G "$toolchain/lib/lib$library.*.dylib" >/dev/null || {
      echo "error: packaged toolchain lacks lib$library" >&2
      exit 1
    }
  done
fi

metadata="$toolchain/share/gnat-patches"
[[ ! -e "$metadata" ]] || {
  echo "error: toolchain metadata destination already exists: $metadata" >&2
  exit 1
}
mkdir -p "$metadata/licenses"
cp "$source_dir/COPYING3" "$metadata/licenses/GPL-3.0.txt"
cp "$source_dir/COPYING.RUNTIME" "$metadata/licenses/GCC-exception-3.1.txt"
cp "$root/README.md" "$metadata/PATCHSET-README.md"
cp "$root/LICENSE" "$metadata/PATCHSET-LICENSE"

aggregate=$(mktemp -d "${TMPDIR:-/tmp}/gnat-patches-aggregate.XXXXXX")
trap 'rm -rf "$aggregate"' EXIT
"$root/scripts/package-patchset.sh" "$patchset" "$major" "$aggregate/package" >/dev/null
cp "$aggregate/package/"*.tar.gz "$metadata/"
cp "$aggregate/package/"*.tar.gz.sha256 "$metadata/"
printf '%s\n' \
  "GNAT native toolchain built by flyology-ada/gnat-patches." \
  "GCC source version: $source_version" \
  "Patchset version: $patchset" \
  "GCC major aggregate: $major" \
  "Platform: $platform" \
  "The embedded patchset archive records source provenance, ordered patches, tests, and checksums." \
  >"$metadata/SOURCE_PROVENANCE.txt"

mkdir -p "$output"
archive_name="gnat-flyology-native-gcc-$source_version-patchset-$patchset-$platform.tar.gz"
archive="$output/$archive_name"
archive_root="gnat_flyology_native-$source_version-patchset.$patchset"
[[ ! -e "$archive" && ! -e "$archive.sha256" ]] || {
  echo "error: toolchain archive already exists: $archive" >&2
  exit 1
}
python3 "$root/scripts/deterministic-archive.py" "$toolchain" "$archive" "$archive_root"
(
  cd "$output"
  shasum -a 256 "$archive_name" >"$archive_name.sha256"
)
echo "$archive"
