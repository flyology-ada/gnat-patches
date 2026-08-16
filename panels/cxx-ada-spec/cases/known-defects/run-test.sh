#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT GCC_VERSION" >&2
  exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
source "$root/scripts/regression-common.sh"
resolve_regression_toolchain "$1"
version=$2
gxx="$REGRESSION_TOOLCHAIN/bin/g++"
[[ -x "$gxx" ]] || {
  echo "error: no g++ in $REGRESSION_TOOLCHAIN" >&2
  exit 1
}

case_root="$root/panels/cxx-ada-spec/cases/known-defects"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-known-defects.XXXXXX")
trap 'rm -rf "$work"' EXIT

check_rejection() {
  local id=$1
  local diagnostic=$2
  local case_dir="$work/$id"
  mkdir -p "$case_dir"
  cp "$case_root/$id.C" "$case_root/${id}_consumer.adb" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c -fdump-ada-spec-slim "$id.C"
  )

  set +e
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f -c "${id}_consumer.adb"
  ) >"$case_dir/build.log" 2>&1
  local status=$?
  set -e

  [[ $status -ne 0 ]] || {
    echo "error: $id unexpectedly generated compilable Ada" >&2
    exit 1
  }
  grep -Eiq "$diagnostic" "$case_dir/build.log" || {
    cat "$case_dir/build.log"
    exit 1
  }
  echo "cxx-ada known defect $id: expected rejection (GCC $version)"
}

check_runtime_defect() {
  local id=$1
  local expected=$2
  local case_dir="$work/$id"
  mkdir -p "$case_dir"
  cp "$case_root/$id.C" "$case_root/${id}_consumer.adb" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c -fdump-ada-spec-slim "$id.C"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "${id}_consumer.adb" -largs "$id.o" -lstdc++
    "${REGRESSION_ENV[@]}" "./${id}_consumer"
  ) >"$case_dir/output.log" 2>&1 || {
    cat "$case_dir/output.log"
    exit 1
  }
  grep -F "$expected" "$case_dir/output.log"
  echo "cxx-ada known defect $id: expected layout mismatch (GCC $version)"
}

check_runtime_defect virtual_inheritance_layout \
  "PASS expected virtual-inheritance mismatch"
