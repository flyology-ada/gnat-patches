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

cxx_fixture="$root/bundles/cxx-ada-generated-name-identity/tests/generated-name-identity.C"
ada_fixture="$root/bundles/cxx-ada-generated-name-identity/tests/generated_name_identity_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-generated-name.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$cxx_fixture" "$ada_fixture" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" \
      -fdump-ada-spec-slim generated-name-identity.C
  )

  set +e
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" generated_name_identity_consumer.adb \
      -largs generated-name-identity.o -lstdc++
    "${REGRESSION_ENV[@]}" ./generated_name_identity_consumer
  ) >"$case_dir/run.log" 2>&1
  run_status=$?
  set -e

  if [[ "$state" == unpatched ]]; then
    [[ $run_status -ne 0 ]] || {
      echo "error: unpatched generated-name regression unexpectedly passed" >&2
      exit 1
    }
    grep -Eiq 'conflicts with declaration|duplicate|not declared|invalid use' \
      "$case_dir/run.log" || {
      cat "$case_dir/run.log"
      exit 1
    }
    echo "cxx-ada-generated-name-identity -O$optimization: expected collision (GCC $version)"
    continue
  fi

  [[ $run_status -eq 0 ]] || {
    cat "$case_dir/run.log"
    exit 1
  }
  spec="$case_dir/generated_name_identity_c.ads"
  grep -F "function inspect_Const_2" "$spec"
  grep -F "function inspect_Const " "$spec"
  grep -F "package Box_int_2 is" "$spec"
  grep -F "subtype Box_int is Box_int_2.Box" "$spec"
  grep -F "the_Widget_2 : int; the_Widget : int" "$spec"
  grep -F "type Tail_Derived_As_Base_2" "$spec"
  grep -F "parent_Base_2 : aliased Left" "$spec"
  grep -F "field_2_Base_2 : aliased Right" "$spec"
  grep -F "package Class_Gadget_2 is" "$spec"
  grep -F "function New_Creator_2" "$spec"
  grep -F "procedure Delete_2" "$spec"
  grep -F "function Assign_Assigner_2" "$spec"
  echo "cxx-ada-generated-name-identity -O$optimization: patched (GCC $version)"
done
