#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then echo "usage: $0 TOOLCHAIN_ROOT GCC_VERSION unpatched|patched" >&2; exit 2; fi
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$root/scripts/regression-common.sh"
resolve_regression_toolchain "$1"
version=$2
state=$3
[[ "$state" == unpatched || "$state" == patched ]] || exit 2
gxx="$REGRESSION_TOOLCHAIN/bin/g++"
cxx="$root/bundles/cxx-ada-enclosing-type-method-names/tests/enclosing-type-method-names.C"
ada="$root/bundles/cxx-ada-enclosing-type-method-names/tests/enclosing_type_method_names_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-type-method.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  dir="$work/O$optimization"; mkdir -p "$dir"; cp "$cxx" "$ada" "$dir/"
  (cd "$dir"; "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" -fdump-ada-spec-slim enclosing-type-method-names.C)
  if [[ "$state" == unpatched ]]; then
    set +e
    (cd "$dir"; "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f -c enclosing_type_method_names_consumer.adb) >"$dir/build.log" 2>&1
    status=$?; set -e
    [[ $status -ne 0 ]] || { echo "error: unpatched binding compiled" >&2; exit 1; }
    grep -Eiq '(left|right).*conflicts' "$dir/build.log"
    echo "cxx-ada-enclosing-type-method-names -O$optimization: expected collision (GCC $version)"
  else
    (cd "$dir"; "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f "-O$optimization" enclosing_type_method_names_consumer.adb -largs enclosing-type-method-names.o -lstdc++; "${REGRESSION_ENV[@]}" ./enclosing_type_method_names_consumer) >"$dir/output.log" 2>&1 || { cat "$dir/output.log"; exit 1; }
    grep -F "function left_Method" "$dir/enclosing_type_method_names_c.ads"
    grep -F "function right_Method" "$dir/enclosing_type_method_names_c.ads"
    grep -Fx "MATCH enclosing type and method names" "$dir/output.log"
    echo "cxx-ada-enclosing-type-method-names -O$optimization: patched (GCC $version)"
  fi
done
