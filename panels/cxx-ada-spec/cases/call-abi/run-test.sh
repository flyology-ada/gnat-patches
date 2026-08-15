#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT GCC_VERSION" >&2
  exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
source "$root/scripts/regression-common.sh"
resolve_regression_toolchain "$1"
version=$2
gxx="$REGRESSION_TOOLCHAIN/bin/g++"
case_root="$root/panels/cxx-ada-spec/cases/call-abi"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-call-abi.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$case_root/call_abi.C" "$case_root/call_abi_consumer.adb" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" \
      -fdump-ada-spec-slim call_abi.C
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" call_abi_consumer.adb -largs call_abi.o -lstdc++
    "${REGRESSION_ENV[@]}" ./call_abi_consumer
  )
  echo "cxx-ada call ABI panel -O$optimization: PASS (GCC $version)"
done
