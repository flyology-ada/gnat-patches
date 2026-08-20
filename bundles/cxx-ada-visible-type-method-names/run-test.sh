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
cxx="$root/bundles/cxx-ada-visible-type-method-names/tests/visible-type-method-names.C"
ada="$root/bundles/cxx-ada-visible-type-method-names/tests/visible_type_method_names_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-visible-method.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  dir="$work/O$optimization"; mkdir -p "$dir"; cp "$cxx" "$ada" "$dir/"
  (cd "$dir"; "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" -fdump-ada-spec-slim visible-type-method-names.C)
  if [[ "$state" == unpatched ]]; then
    set +e
    (cd "$dir"; "${REGRESSION_ENV[@]}" "$REGRESSION_GCC" -c visible_type_method_names_c.ads) >"$dir/build.log" 2>&1
    status=$?; set -e
    [[ $status -ne 0 ]] || { echo "error: unpatched visible type/method binding compiled" >&2; exit 1; }
    grep -Eiq '(result).*not visible|multiple use clauses cause hiding' "$dir/build.log"
    echo "cxx-ada-visible-type-method-names -O$optimization: expected hiding (GCC $version)"
  else
    grep -F "function result_Method" "$dir/visible_type_method_names_c.ads"
    (cd "$dir"; "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f "-O$optimization" visible_type_method_names_consumer.adb -largs visible-type-method-names.o -lstdc++; "${REGRESSION_ENV[@]}" ./visible_type_method_names_consumer) >"$dir/output.log" 2>&1 || { cat "$dir/output.log"; exit 1; }
    grep -Fx "MATCH visible type and method names" "$dir/output.log"
    echo "cxx-ada-visible-type-method-names -O$optimization: patched (GCC $version)"
  fi
done
