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
target=$("${REGRESSION_ENV[@]}" "$gxx" -dumpmachine)
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
    output=$("${REGRESSION_ENV[@]}" ./call_abi_consumer)
    printf '%s\n' "$output"

    if [[ $'\n'"$output"$'\n' == *$'\nLONG_DOUBLE MATCH\n'* ]]; then
      :
    elif [[ $'\n'"$output"$'\n' == *$'\nLONG_DOUBLE MISMATCH\n'* ]] &&
         [[ "$target" == aarch64*-linux* ]]; then
      echo "cxx-ada call ABI long double: TARGET BOUNDARY ($target)"
    else
      echo "unexpected long double call ABI result for $target" >&2
      exit 1
    fi
  )
  echo "cxx-ada call ABI panel -O$optimization: PASS (GCC $version)"
done
