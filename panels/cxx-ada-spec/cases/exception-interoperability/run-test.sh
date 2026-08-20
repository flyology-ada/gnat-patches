#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then echo "usage: $0 TOOLCHAIN_ROOT GCC_VERSION" >&2; exit 2; fi
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
source "$root/scripts/regression-common.sh"
resolve_regression_toolchain "$1"
version=$2
gxx="$REGRESSION_TOOLCHAIN/bin/g++"
case_root="$root/panels/cxx-ada-spec/cases/exception-interoperability"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-exceptions.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  dir="$work/O$optimization"; mkdir -p "$dir"
  cp "$case_root/exception_interoperability.C" "$case_root/exception_interoperability_consumer.adb" "$dir/"
  (cd "$dir"; "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" -fdump-ada-spec-slim exception_interoperability.C; "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f "-O$optimization" exception_interoperability_consumer.adb -largs exception_interoperability.o -lstdc++; "${REGRESSION_ENV[@]}" ./exception_interoperability_consumer) >"$dir/output.log" 2>&1 || { cat "$dir/output.log"; exit 1; }
  grep -Fx "MATCH C++ exception interoperability" "$dir/output.log"
  echo "cxx-ada exception interoperability -O$optimization: PASS (GCC $version)"
done
