#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 GCC_SOURCE BUILD_DIR INSTALL_DIR" >&2
  exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
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
  --enable-languages=c,c++,ada
  --enable-libada
  --disable-bootstrap
  --disable-multilib
  --disable-nls
  --disable-libsanitizer
  --disable-libgomp
  --disable-libquadmath
  --disable-libssp
)

host_os=$(uname -s)
case $host_os in
  Darwin|Linux) ;;
  *) echo "error: unsupported build host" >&2; exit 1 ;;
esac
fallback_host_cxx() {
  if [[ $host_os == Darwin ]]; then
    "$root/scripts/homebrew-gxx.sh"
  else
    printf '%s\n' /usr/bin/g++
  fi
}
using_fallback=false
host_cxx=${GNAT_PATCHES_HOST_CXX:-$(command -v g++ || true)}
host_cxx=$(command -v "$host_cxx" || true)
if [[ -z "$host_cxx" && -z ${GNAT_PATCHES_HOST_CXX:-} ]]; then
  host_cxx=$(fallback_host_cxx)
  using_fallback=true
elif [[ -z "$host_cxx" ]]; then
  echo "error: requested host C++ compiler is unavailable" >&2; exit 1
fi
probe=$build_dir/.host-cxx-probe
if [[ -z ${GNAT_PATCHES_HOST_CXX:-} ]] &&
   ! printf 'int main() { return 0; }\n' |
     "$host_cxx" -x c++ - -o "$probe" >/dev/null 2>&1; then
  host_cxx=$(fallback_host_cxx)
  using_fallback=true
fi
rm -f "$probe"

if [[ $(uname -s) == Darwin ]]; then
  [[ $(uname -m) == arm64 || $(uname -m) == aarch64 ]] || {
    echo "error: only macOS arm64 is supported" >&2; exit 1;
  }
  sdk=$(xcrun --sdk macosx --show-sdk-path)
  real_gnatmake=$(command -v gnatmake)
  bootstrap_wrapper_dir=$build_dir/bootstrap-wrappers
  mkdir -p "$bootstrap_wrapper_dir"
  ln -s "$root/scripts/bootstrap-gnatmake.sh" \
    "$bootstrap_wrapper_dir/gnatmake"
  export GNAT_PATCHES_REAL_GNATMAKE=$real_gnatmake
  export PATH="$bootstrap_wrapper_dir:$PATH"
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
configure_env=("CXX=$host_cxx")
if $using_fallback && [[ $host_os == Linux ]]; then
  configure_env+=(
    "CXXFLAGS=${CXXFLAGS:+$CXXFLAGS }-g -O2 -fno-PIE"
    "LDFLAGS=${LDFLAGS:+$LDFLAGS }-no-pie"
  )
fi
(cd "$build_dir" && env "${configure_env[@]}" "${configure[@]}")
make -C "$build_dir" -j "$jobs" all-gcc all-target-libgcc all-target-libatomic \
  all-target-libstdc++-v3 all-target-libada
make -C "$build_dir" -j "$jobs" all-gnattools
make -C "$build_dir" -j 1 install-gcc install-target-libgcc \
  install-target-libatomic install-target-libstdc++-v3 install-target-libada
if [[ $host_os == Darwin ]]; then
  fixed_count=$("$root/scripts/quarantine-darwin-include-fixed.sh" \
    "$install_dir" build-sdk)
  echo "Darwin compiler: quarantined $fixed_count SDK-derived include-fixed directory" >&2
fi
"$install_dir/bin/gcc" -v
"$install_dir/bin/g++" --version
"$install_dir/bin/gnatmake" --version
