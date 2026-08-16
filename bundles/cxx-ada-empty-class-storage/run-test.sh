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

cxx_fixture="$root/bundles/cxx-ada-empty-class-storage/tests/empty-class-storage.C"
ada_fixture="$root/bundles/cxx-ada-empty-class-storage/tests/empty_class_storage_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-empty-storage.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$cxx_fixture" "$ada_fixture" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -std=c++20 -c "-O$optimization" \
      -fdump-ada-spec-slim empty-class-storage.C
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" empty_class_storage_consumer.adb \
      -largs empty-class-storage.o -lstdc++
    "${REGRESSION_ENV[@]}" ./empty_class_storage_consumer
  ) >"$case_dir/output.log" 2>&1 || {
    cat "$case_dir/output.log"
    exit 1
  }

  spec="$case_dir/empty_class_storage_c.ads"
  if [[ "$state" == unpatched ]]; then
    grep -Fx "EMPTY MISMATCH" "$case_dir/output.log"
    grep -Fx "METHOD_EMPTY MATCH" "$case_dir/output.log"
    grep -Fx "EBO MATCH" "$case_dir/output.log"
    grep -Fx "MEMBER MISMATCH" "$case_dir/output.log"
    grep -Fx "ARRAY MATCH" "$case_dir/output.log"
    grep -Fx "NO_UNIQUE_ADDRESS MATCH" "$case_dir/output.log"
    if grep -Fq "for Empty'Object_Size use" "$spec"; then
      echo "error: unpatched mapper unexpectedly emitted empty-class size" >&2
      exit 1
    fi
    echo "cxx-ada-empty-class-storage -O$optimization: expected mismatches (GCC $version)"
    continue
  fi

  grep -F "for Empty'Size use 0;" "$spec"
  grep -F "for Empty'Object_Size use 8;" "$spec"
  if grep -Fq "parent : aliased Empty_Base;" "$spec" \
    || grep -Fq "ignored : aliased Empty;" "$spec"; then
    echo "error: patched mapper retained an ABI-overlapping empty field" >&2
    exit 1
  fi
  grep -Fx "EMPTY MATCH" "$case_dir/output.log"
  grep -Fx "METHOD_EMPTY MATCH" "$case_dir/output.log"
  grep -Fx "EBO MATCH" "$case_dir/output.log"
  grep -Fx "MEMBER MATCH" "$case_dir/output.log"
  grep -Fx "ARRAY MATCH" "$case_dir/output.log"
  grep -Fx "NO_UNIQUE_ADDRESS MATCH" "$case_dir/output.log"
  echo "cxx-ada-empty-class-storage -O$optimization: patched (GCC $version)"
done
