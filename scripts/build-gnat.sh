#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 GCC_SOURCE BUILD_DIR INSTALL_DIR" >&2
  exit 2
fi

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

configure=(
  "$source_dir/configure"
  "--prefix=$install_dir"
  --enable-languages=c,ada
  --enable-libada
  --disable-bootstrap
  --disable-multilib
  --disable-nls
  --disable-libsanitizer
  --disable-libgomp
  --disable-libquadmath
  --disable-libssp
)

if [[ $(uname -s) == Darwin ]]; then
  [[ $(uname -m) == arm64 || $(uname -m) == aarch64 ]] || {
    echo "error: only macOS arm64 is supported" >&2; exit 1;
  }
  sdk=$(xcrun --sdk macosx --show-sdk-path)
  configure+=(
    "--with-build-sysroot=$sdk"
    "--with-specs=%{!-sysroot=*:--sysroot=%:if-exists-else(/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk)}"
    "--with-gmp=$(brew --prefix gmp)"
    "--with-mpfr=$(brew --prefix mpfr)"
    "--with-mpc=$(brew --prefix libmpc)"
  )
else
  configure+=(--enable-threads=posix --with-system-zlib)
fi

jobs=${GNAT_PATCHES_JOBS:-2}
(cd "$build_dir" && "${configure[@]}")
make -C "$build_dir" -j "$jobs" all-gcc all-target-libgcc all-target-libatomic \
  all-target-libada
make -C "$build_dir" -j "$jobs" all-gnattools
make -C "$build_dir" -j 1 install-gcc install-target-libgcc \
  install-target-libatomic install-target-libada
"$install_dir/bin/gcc" -v
"$install_dir/bin/gnatmake" --version
