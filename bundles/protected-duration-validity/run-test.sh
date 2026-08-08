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

  if [[ "$state" == unpatched && "$optimization" == 2 && \
        "$target" == x86_64*-linux* ]]; then
    [[ $build_status -ne 0 ]] || {
      echo "error: unpatched protected-Duration regression unexpectedly compiled at -O2"
      exit 1
    }
    grep -Eiq 'GNAT BUG DETECTED|fold_convert_loc' "$case_dir/build.log" || {
      cat "$case_dir/build.log"
      exit 1
    }
    echo "protected-duration-validity -O2: expected compiler failure ($target)"
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
