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
cxx="$root/bundles/cxx-ada-profile-formal-type-names/tests/profile-formal-type-names.C"
ada="$root/bundles/cxx-ada-profile-formal-type-names/tests/profile_formal_type_names_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-profile-name.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  dir="$work/O$optimization"; mkdir -p "$dir"; cp "$cxx" "$ada" "$dir/"
  (cd "$dir"; "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" -fdump-ada-spec-slim profile-formal-type-names.C)
  if [[ "$state" == unpatched ]]; then
    set +e
    (cd "$dir"; "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f -c profile_formal_type_names_consumer.adb) >"$dir/build.log" 2>&1
    status=$?; set -e
    [[ $status -ne 0 ]] || { echo "error: unpatched binding compiled" >&2; exit 1; }
    grep -Eiq 'formal parameter.*cannot be used before end of specification' "$dir/build.log"
    echo "cxx-ada-profile-formal-type-names -O$optimization: expected collision (GCC $version)"
  else
    (cd "$dir"; "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f "-O$optimization" profile_formal_type_names_consumer.adb -largs profile-formal-type-names.o -lstdc++; "${REGRESSION_ENV[@]}" ./profile_formal_type_names_consumer) >"$dir/output.log" 2>&1 || { cat "$dir/output.log"; exit 1; }
    grep -F "function New_Widget (the_widget : int)" "$dir/profile_formal_type_names_c.ads"
    grep -F "function make_result (the_result : int)" "$dir/profile_formal_type_names_c.ads"
    grep -F "function inspect (the_result : int; item : access Result)" "$dir/profile_formal_type_names_c.ads"
    grep -Fx "MATCH profile formal and type names" "$dir/output.log"
    echo "cxx-ada-profile-formal-type-names -O$optimization: patched (GCC $version)"
  fi
done
