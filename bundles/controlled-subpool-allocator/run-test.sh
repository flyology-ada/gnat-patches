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

case "$version" in
  13.2.0|14.2.0|15.1.0) affected=yes ;;
  15.3.0|16.1.0|16.2.0) affected=no ;;
  *) echo "error: unsupported GCC version: $version" >&2; exit 2 ;;
esac

fixture="$root/bundles/controlled-subpool-allocator/tests/controlled_subpool_allocator.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-controlled-subpool-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$fixture" "$case_dir/controlled_subpool_allocator.adb"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" -gnata controlled_subpool_allocator.adb
  )

  set +e
  "${REGRESSION_ENV[@]}" "$case_dir/controlled_subpool_allocator" \
    >"$case_dir/output.log" 2>&1
  run_status=$?
  set -e

  if [[ "$state" == unpatched && "$affected" == yes ]]; then
    [[ $run_status -ne 0 ]] || {
      echo "error: unpatched controlled-subpool regression unexpectedly passed at -O$optimization" >&2
      exit 1
    }
    grep -Eiq 'PROGRAM_ERROR.*Default_Subpool_For_Pool' "$case_dir/output.log" || {
      cat "$case_dir/output.log"
      exit 1
    }
    expected=expected-null-subpool-failure
  else
    [[ $run_status -eq 0 ]] || { cat "$case_dir/output.log"; exit 1; }
    grep -Fx "PASS controlled named subpool allocator" "$case_dir/output.log"
    if [[ "$affected" == no ]]; then
      expected=known-good-control
    else
      expected=patched
    fi
  fi

  echo "controlled-subpool-allocator -O$optimization: $expected (GCC $version)"
done
