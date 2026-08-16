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
[[ "$state" == unpatched || "$state" == patched ]] || {
  echo "error: state must be unpatched or patched" >&2
  exit 2
}

gxx="$REGRESSION_TOOLCHAIN/bin/g++"
cxx="$root/bundles/cxx-ada-virtual-diamond-layout/tests/virtual-diamond-layout.C"
ada="$root/bundles/cxx-ada-virtual-diamond-layout/tests/virtual_diamond_layout_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-virtual-diamond.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$cxx" "$ada" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" \
      -fdump-ada-spec-slim virtual-diamond-layout.C
  )

  spec="$case_dir/virtual_diamond_layout_c.ads"
  if [[ "$state" == unpatched ]]; then
    (
      cd "$case_dir"
      "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
        "-O$optimization" virtual_diamond_layout_consumer.adb \
        -largs virtual-diamond-layout.o -lstdc++
    ) >"$case_dir/build.log" 2>&1
    set +e
    (
      cd "$case_dir"
      "${REGRESSION_ENV[@]}" ./virtual_diamond_layout_consumer
    ) >"$case_dir/output.log" 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]] || {
      echo "error: unpatched virtual diamond layout matched" >&2
      exit 1
    }
    grep -Fq 'C++ and Ada virtual diamond layouts differ' \
      "$case_dir/output.log"
    if grep -Fq "type Diamond_Left_As_Base" "$spec"; then
      echo "error: unpatched mapper unexpectedly emitted as-base storage" >&2
      exit 1
    fi
    echo "cxx-ada-virtual-diamond-layout -O$optimization: expected mismatch (GCC $version)"
    continue
  fi

  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" virtual_diamond_layout_consumer.adb \
      -largs virtual-diamond-layout.o -lstdc++
    "${REGRESSION_ENV[@]}" ./virtual_diamond_layout_consumer
  ) >"$case_dir/output.log" 2>&1 || {
    cat "$case_dir/output.log"
    exit 1
  }

  grep -F "type Diamond_Left_As_Base" "$spec"
  grep -F "for Diamond_Left_As_Base'Object_Size use" "$spec"
  grep -F "type Diamond_Right_As_Base" "$spec"
  grep -F "for Diamond_Right_As_Base'Object_Size use" "$spec"
  grep -F "parent : aliased Diamond_Left_As_Base" "$spec"
  grep -F "field_2 : aliased Diamond_Right_As_Base" "$spec"
  grep -Fx "MATCH C++ Ada virtual diamond layout" "$case_dir/output.log"
  echo "cxx-ada-virtual-diamond-layout -O$optimization: patched (GCC $version)"
done
