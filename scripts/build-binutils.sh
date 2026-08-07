#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 BINUTILS_SOURCE BUILD_DIR INSTALL_DIR" >&2
  exit 2
fi

[[ $(uname -s) == Linux ]] || {
  echo "error: packaged GNU Binutils helpers are Linux-only" >&2
  exit 1
}
source_dir=$(cd "$1" && pwd)
build_dir=$2
install_dir=$3
[[ ! -e "$build_dir" && ! -e "$install_dir" ]] || {
  echo "error: build and install destinations must not exist" >&2
  exit 1
}
mkdir -p "$build_dir" "$install_dir"
build_dir=$(cd "$build_dir" && pwd)
install_dir=$(cd "$install_dir" && pwd)
multiarch=$(gcc -print-multiarch)
lib_path="/lib:/usr/lib:/lib64:/usr/lib64"
if [[ -n "$multiarch" ]]; then
  lib_path="/lib/$multiarch:/usr/lib/$multiarch:$lib_path"
fi

(
  cd "$build_dir"
  "$source_dir/configure" \
    "--prefix=$install_dir" \
    --disable-nls \
    --disable-shared \
    --disable-werror \
    --with-zlib \
    --without-zstd \
    --disable-compressed-debug-sections \
    --disable-separate-code \
    --disable-gdb \
    --disable-sim \
    --disable-readline \
    --with-sysroot=/ \
    "--with-lib-path=$lib_path" \
    --enable-lto
)
jobs=${GNAT_PATCHES_JOBS:-2}
make -C "$build_dir" -j "$jobs" all-binutils all-gas all-ld
make -C "$build_dir" -j 1 install-binutils install-gas install-ld
mkdir -p "$install_dir/share/gnat-patches-binutils"
cp "$source_dir/COPYING3" "$install_dir/share/gnat-patches-binutils/GPL-3.0.txt"
cp "$source_dir/COPYING.LIB" "$install_dir/share/gnat-patches-binutils/LGPL.txt"
printf '%s\n' \
  "GNU Binutils 2.46.1 built from the checksum-pinned Sourceware release." \
  "Build flags and version derive from alire-project/GNAT-FSF-builds/specs/binutils.anod." \
  "Corresponding source is attached to each gnat_flyology_native release." \
  >"$install_dir/share/gnat-patches-binutils/SOURCE_PROVENANCE.txt"
"$install_dir/bin/as" --version | sed -n '1p'
"$install_dir/bin/ld" --version | sed -n '1p'
