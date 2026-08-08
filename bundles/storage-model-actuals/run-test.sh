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

fixture="$root/bundles/storage-model-actuals/tests/storage_model_actuals.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-storage-model-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$fixture" "$case_dir/storage_model_actuals.adb"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -gnatX0 -gnata \
      "-O$optimization" storage_model_actuals.adb
  )
  set +e
  "${REGRESSION_ENV[@]}" "$case_dir/storage_model_actuals" \
    >"$case_dir/output.log" 2>&1
  status=$?
  set -e

  if [[ "$version" == 13.2.0 ]]; then
    [[ $status -eq 0 ]] || { cat "$case_dir/output.log"; exit 1; }
    grep -F "PASS reads= 15 writes= 8 read_bytes= 92 write_bytes= 80" \
      "$case_dir/output.log"
    expected=known-good-control
  elif [[ "$state" == patched ]]; then
    [[ $status -eq 0 ]] || { cat "$case_dir/output.log"; exit 1; }
    grep -F "PASS reads= 16 writes= 8 read_bytes= 100 write_bytes= 80" \
      "$case_dir/output.log"
    expected=patched
  else
    [[ $status -ne 0 ]] || {
      echo "error: unpatched storage-model regression unexpectedly passed at -O$optimization"
      exit 1
    }
    grep -Eiq 'CONSTRAINT_ERROR|erroneous memory access' "$case_dir/output.log" || {
      cat "$case_dir/output.log"
      exit 1
    }
    expected=expected-failure
  fi
  echo "storage-model-actuals -O$optimization: $expected"
done
