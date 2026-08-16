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
[[ -x "$gxx" ]] || {
  echo "error: no g++ in $REGRESSION_TOOLCHAIN" >&2
  exit 1
}

cxx_fixture="$root/bundles/cxx-ada-virtual-inheritance-layout/tests/virtual-inheritance-layout.C"
ada_fixture="$root/bundles/cxx-ada-virtual-inheritance-layout/tests/virtual_inheritance_layout_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-virtual-layout.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$cxx_fixture" "$ada_fixture" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" \
      -fdump-ada-spec-slim virtual-inheritance-layout.C
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" virtual_inheritance_layout_consumer.adb \
      -largs virtual-inheritance-layout.o -lstdc++
    "${REGRESSION_ENV[@]}" ./virtual_inheritance_layout_consumer
  ) >"$case_dir/output.log" 2>&1 || {
    cat "$case_dir/output.log"
    exit 1
  }

  spec="$case_dir/virtual_inheritance_layout_c.ads"
  if [[ "$state" == unpatched ]]; then
    grep -Fx "MISMATCH C++ Ada virtual inheritance" "$case_dir/output.log"
    if grep -Fq "for Virtual'Object_Size use" "$spec"; then
      echo "error: unpatched mapper unexpectedly emitted virtual layout" >&2
      exit 1
    fi
    echo "cxx-ada-virtual-inheritance-layout -O$optimization: expected mismatch (GCC $version)"
    continue
  fi

  grep -F "for Virtual'Size use" "$spec"
  grep -F "for Virtual'Object_Size use" "$spec"
  grep -F "for Virtual'Alignment use" "$spec"
  grep -F "derived_value at" "$spec"
  grep -F "field_2 at" "$spec"
  grep -Fx "MATCH C++ Ada virtual inheritance" "$case_dir/output.log"
  echo "cxx-ada-virtual-inheritance-layout -O$optimization: patched (GCC $version)"
done
