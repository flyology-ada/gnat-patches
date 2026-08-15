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

cxx_fixture="$root/bundles/cxx-ada-namespace-identity/tests/namespace-identity.C"
ada_fixture="$root/bundles/cxx-ada-namespace-identity/tests/namespace_identity_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-namespace-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$cxx_fixture" "$ada_fixture" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" \
      -fdump-ada-spec-slim namespace-identity.C
  )

  spec="$case_dir/namespace_identity_c.ads"
  set +e
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" -c namespace_identity_consumer.adb
  ) >"$case_dir/build.log" 2>&1
  build_status=$?
  set -e

  if [[ "$state" == unpatched ]]; then
    [[ $build_status -ne 0 ]] || {
      echo "error: unpatched namespace regression unexpectedly compiled" >&2
      exit 1
    }
    grep -Eiq 'conflicts with declaration|duplicate|already declared' \
      "$case_dir/build.log" || {
      cat "$case_dir/build.log"
      exit 1
    }
    echo "cxx-ada-namespace-identity -O$optimization: expected collision (GCC $version)"
    continue
  fi

  [[ $build_status -eq 0 ]] || {
    cat "$case_dir/build.log"
    exit 1
  }
  grep -F "type first_inner_Item" "$spec"
  grep -F "type second_inner_Item" "$spec"
  grep -F "function first_inner_transform" "$spec"
  grep -F "function second_inner_transform" "$spec"
  grep -F "package Class_first_inner_Object" "$spec"
  grep -F "package Class_second_inner_Object" "$spec"
  echo "cxx-ada-namespace-identity -O$optimization: patched (GCC $version)"
done
