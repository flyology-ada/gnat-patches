#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then echo "usage: $0 TOOLCHAIN_ROOT GCC_VERSION" >&2; exit 2; fi
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
source "$root/scripts/regression-common.sh"
resolve_regression_toolchain "$1"
version=$2
gxx="$REGRESSION_TOOLCHAIN/bin/g++"
case_root="$root/panels/cxx-ada-spec/cases/stdlib-value-facade"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-stdlib.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  dir="$work/O$optimization"; mkdir -p "$dir"
  cp "$case_root/stdlib_direct.C" "$case_root/stdlib_facade.C" "$case_root/stdlib_facade_consumer.adb" "$dir/"
  (cd "$dir"; "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" -fdump-ada-spec-slim stdlib_direct.C)
  grep -F "function echo_string" "$dir/stdlib_direct_c.ads"
  set +e
  (cd "$dir"; "${REGRESSION_ENV[@]}" "$REGRESSION_GCC" -c stdlib_direct_c.ads) >"$dir/direct.log" 2>&1
  direct_status=$?
  set -e
  [[ $direct_status -ne 0 ]] || { echo "error: direct std::string slim binding unexpectedly compiled" >&2; exit 1; }
  grep -Eiq 'file .*\.ads.*not found' "$dir/direct.log"

  (cd "$dir"; "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" -fdump-ada-spec-slim stdlib_facade.C; "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f "-O$optimization" stdlib_facade_consumer.adb -largs stdlib_facade.o -lstdc++; "${REGRESSION_ENV[@]}" ./stdlib_facade_consumer) >"$dir/output.log" 2>&1 || { cat "$dir/output.log"; exit 1; }
  grep -Fx "MATCH nontrivial standard-library facade" "$dir/output.log"
  echo "cxx-ada standard-library value facade -O$optimization: PASS (GCC $version)"
done
