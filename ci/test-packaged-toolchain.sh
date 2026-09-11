#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT GPRBUILD_ROOT PLATFORM" >&2
  exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
toolchain=$(cd "$1" && pwd)
gprbuild_root=$(cd "$2" && pwd)
platform=$3
case "$platform" in
  linux-x86_64) expected_target=x86_64-pc-linux-gnu ;;
  linux-aarch64) expected_target=aarch64-linux-gnu ;;
  macos-aarch64) expected_target='aarch64-apple-darwin*' ;;
  *) echo "error: unsupported packaged toolchain platform: $platform" >&2; exit 2 ;;
esac

source "$root/scripts/regression-common.sh"
resolve_regression_toolchain "$toolchain"
actual_target=$("${REGRESSION_ENV[@]}" "$REGRESSION_GCC" -dumpmachine)
[[ "$actual_target" == $expected_target ]] || {
  echo "error: packaged compiler reports $actual_target, expected $expected_target" >&2
  exit 1
}

gprbuild="$gprbuild_root/bin/gprbuild"
[[ -x "$gprbuild" ]] || {
  echo "error: maintained GPRbuild is missing: $gprbuild" >&2
  exit 1
}
"$gprbuild" --version | grep -F 'GPRBUILD 26.0.0' >/dev/null || {
  echo "error: maintained GPRbuild has an unexpected binary version" >&2
  exit 1
}

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/packaged-toolchain-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
cp -R "$root/ci/packaged-toolchain/." "$test_dir/"
(
  cd "$test_dir"
  "${REGRESSION_ENV[@]}" \
    "PATH=$gprbuild_root/bin:$toolchain/bin:$PATH" \
    "$gprbuild" -p -P one_main.gpr
  [[ -x bin/one_main ]] || {
    echo "error: GPRbuild returned without creating the one-main executable" >&2
    exit 1
  }
  [[ $("${REGRESSION_ENV[@]}" bin/one_main) == "packaged toolchain: PASS" ]]
)

echo "packaged toolchain: PASS $platform ($actual_target)"
