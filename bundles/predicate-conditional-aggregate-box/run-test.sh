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

# GCC 13 and 14 expand the inner aggregate before the predicate check relocates
# the conditional expression, so they compile and run the fixture unchanged and
# are unpatched known-good controls.
control=no
case "$version" in
  13.2.0 | 14.2.0) control=yes ;;
esac

fixture="$root/bundles/predicate-conditional-aggregate-box/tests/predicate_conditional_aggregate_box.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-predicate-conditional-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$fixture" "$case_dir/predicate_conditional_aggregate_box.adb"
  set +e
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f -gnat2022 \
      "-O$optimization" predicate_conditional_aggregate_box.adb
  ) >"$case_dir/build.log" 2>&1
  build_status=$?
  set -e

  if [[ "$control" == no && "$state" == unpatched ]]; then
    [[ $build_status -ne 0 ]] || {
      echo "error: unpatched predicate-conditional regression unexpectedly compiled at -O$optimization" >&2
      exit 1
    }
    if ! grep -Fq 'GNAT BUG DETECTED' "$case_dir/build.log" ||
       ! grep -Fq 'in gnat_to_gnu' "$case_dir/build.log"; then
      cat "$case_dir/build.log"
      exit 1
    fi
    echo "predicate-conditional-aggregate-box -O$optimization: expected front-end abort (GCC $version)"
    continue
  fi

  [[ $build_status -eq 0 ]] || { cat "$case_dir/build.log"; exit 1; }
  "${REGRESSION_ENV[@]}" "$case_dir/predicate_conditional_aggregate_box" \
    >"$case_dir/output.log" 2>&1 || {
      cat "$case_dir/output.log"
      exit 1
    }
  grep -F "PASS predicate conditional aggregate box" "$case_dir/output.log"
  if [[ "$control" == yes ]]; then
    expected=known-good-control
  else
    expected=patched
  fi
  echo "predicate-conditional-aggregate-box -O$optimization: $expected (GCC $version)"
done
