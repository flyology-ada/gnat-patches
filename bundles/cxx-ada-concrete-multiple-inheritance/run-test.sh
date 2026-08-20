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
cxx="$root/bundles/cxx-ada-concrete-multiple-inheritance/tests/concrete-multiple-inheritance.C"
ada="$root/bundles/cxx-ada-concrete-multiple-inheritance/tests/concrete_multiple_inheritance_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-concrete-mi.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  dir="$work/O$optimization"; mkdir -p "$dir"; cp "$cxx" "$ada" "$dir/"
  (cd "$dir"; "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" -fdump-ada-spec-slim concrete-multiple-inheritance.C)
  if [[ "$state" == unpatched ]]; then
    grep -F "type Both is limited new Left and Right with record" "$dir/concrete_multiple_inheritance_c.ads"
    set +e
    (cd "$dir"; "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f -c concrete_multiple_inheritance_consumer.adb) >"$dir/build.log" 2>&1
    status=$?; set -e
    [[ $status -ne 0 ]] || { echo "error: unpatched concrete MI binding compiled" >&2; exit 1; }
    grep -Eiq '(interface|progenitor)' "$dir/build.log"
    echo "cxx-ada-concrete-multiple-inheritance -O$optimization: expected rejection (GCC $version)"
  else
    grep -F "type Both is limited new Left with record" "$dir/concrete_multiple_inheritance_c.ads"
    grep -F "field_2 : aliased Right_As_Base;" "$dir/concrete_multiple_inheritance_c.ads"
    grep -F "field_2 at 16 range 0 .. 95;" "$dir/concrete_multiple_inheritance_c.ads"
    (cd "$dir"; "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f "-O$optimization" concrete_multiple_inheritance_consumer.adb -largs concrete-multiple-inheritance.o -lstdc++; "${REGRESSION_ENV[@]}" ./concrete_multiple_inheritance_consumer) >"$dir/output.log" 2>&1 || { cat "$dir/output.log"; exit 1; }
    grep -Fx "MATCH nested concrete multiple inheritance" "$dir/output.log"
    echo "cxx-ada-concrete-multiple-inheritance -O$optimization: patched (GCC $version)"
  fi
done
