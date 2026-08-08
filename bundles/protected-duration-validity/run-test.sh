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

target=$("${REGRESSION_ENV[@]}" "$REGRESSION_GCC" -dumpmachine)
fixture="$root/bundles/protected-duration-validity/tests/protected_duration_validity.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-protected-duration-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

# The stale check is in the tree on every target, but it only becomes
# observable where the automatic lock-free implementation is selected for this
# protected type. Linux x86-64 is the target where that is demonstrable: the
# optimized build aborts in the front end and the unoptimized build rejects a
# valid negative Duration at run time. Other targets execute the round trip
# unchanged before the patch and are unpatched target controls.
demonstrable=no
[[ "$target" != x86_64*-linux* ]] || demonstrable=yes

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$fixture" "$case_dir/protected_duration_validity.adb"
  set +e
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" -gnatVa protected_duration_validity.adb
  ) >"$case_dir/build.log" 2>&1
  build_status=$?
  set -e

  if [[ "$state" == unpatched && "$demonstrable" == yes ]]; then
    if [[ "$optimization" == 2 ]]; then
      [[ $build_status -ne 0 ]] || {
        echo "error: unpatched protected-Duration regression unexpectedly compiled at -O2" >&2
        exit 1
      }
      grep -Eiq 'GNAT BUG DETECTED|fold_convert_loc' "$case_dir/build.log" || {
        cat "$case_dir/build.log"
        exit 1
      }
      echo "protected-duration-validity -O2: expected compiler abort ($target, GCC $version)"
      continue
    fi

    [[ $build_status -eq 0 ]] || { cat "$case_dir/build.log"; exit 1; }
    set +e
    "${REGRESSION_ENV[@]}" "$case_dir/protected_duration_validity" \
      >"$case_dir/output.log" 2>&1
    run_status=$?
    set -e
    [[ $run_status -ne 0 ]] || {
      echo "error: unpatched protected-Duration regression unexpectedly passed at -O0" >&2
      exit 1
    }
    if ! grep -Eiq 'CONSTRAINT_ERROR' "$case_dir/output.log" ||
       ! grep -Eiq 'invalid data' "$case_dir/output.log"; then
      cat "$case_dir/output.log"
      exit 1
    fi
    echo "protected-duration-validity -O0: expected invalid-data rejection ($target, GCC $version)"
    continue
  fi

  [[ $build_status -eq 0 ]] || { cat "$case_dir/build.log"; exit 1; }
  "${REGRESSION_ENV[@]}" "$case_dir/protected_duration_validity" \
    >"$case_dir/output.log" 2>&1 || {
      cat "$case_dir/output.log"
      exit 1
    }
  grep -F "PASS protected Duration validity" "$case_dir/output.log"
  if [[ "$state" == unpatched ]]; then
    expected=target-control
  else
    expected=patched
  fi
  echo "protected-duration-validity -O$optimization: $expected ($target, GCC $version)"
done
