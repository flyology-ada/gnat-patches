#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT GCC_VERSION unpatched|patched" >&2
  exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$root/scripts/regression-common.sh"
resolve_regression_toolchain "$1"
version=$2
state=$3
[[ "$state" == unpatched || "$state" == patched ]] || exit 2
gxx="$REGRESSION_TOOLCHAIN/bin/g++"
cxx="$root/bundles/cxx-ada-derived-virtual-slots/tests/derived-virtual-slots.C"
ada="$root/bundles/cxx-ada-derived-virtual-slots/tests/derived_virtual_slots_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-derived-slots.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  dir="$work/O$optimization"
  mkdir -p "$dir"
  cp "$cxx" "$ada" "$dir/"
  (
    cd "$dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" \
      -fdump-ada-spec-slim derived-virtual-slots.C
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" derived_virtual_slots_consumer.adb \
      -largs derived-virtual-slots.o -lstdc++
  ) >"$dir/build.log" 2>&1 || { cat "$dir/build.log"; exit 1; }

  if [[ "$state" == unpatched ]]; then
    grep -F "procedure Delete_Derived" "$dir/derived_virtual_slots_c.ads"
    set +e
    (cd "$dir"; "${REGRESSION_ENV[@]}" ./derived_virtual_slots_consumer) \
      >"$dir/output.log" 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]] || {
      echo "error: unpatched derived virtual slot unexpectedly dispatched" >&2
      exit 1
    }
    echo "cxx-ada-derived-virtual-slots -O$optimization: expected bad dispatch (GCC $version)"
  else
    grep -F "procedure Delete (this : access Derived'Class)" "$dir/derived_virtual_slots_c.ads"
    grep -F "procedure Delete_And_Free (this : access Derived'Class)" "$dir/derived_virtual_slots_c.ads"
    grep -F "function Delete_Method (this : access Base'Class)" "$dir/derived_virtual_slots_c.ads"
    (cd "$dir"; "${REGRESSION_ENV[@]}" ./derived_virtual_slots_consumer) \
      >"$dir/output.log" 2>&1 || { cat "$dir/output.log"; exit 1; }
    grep -Fx "MATCH derived virtual slots" "$dir/output.log"
    echo "cxx-ada-derived-virtual-slots -O$optimization: patched (GCC $version)"
  fi
done
