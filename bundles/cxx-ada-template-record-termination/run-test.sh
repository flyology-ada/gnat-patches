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

cxx_fixture="$root/bundles/cxx-ada-template-record-termination/tests/template-record-termination.C"
ada_fixture="$root/bundles/cxx-ada-template-record-termination/tests/template_record_termination_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-template-record-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$cxx_fixture" "$ada_fixture" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -std=gnu++20 -c "-O$optimization" \
      -fdump-ada-spec-slim template-record-termination.C
  )

  spec="$case_dir/template_record_termination_c.ads"
  [[ -f "$spec" ]] || {
    echo "error: g++ did not generate $spec" >&2
    exit 1
  }

  set +e
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" -c template_record_termination_consumer.adb
  ) >"$case_dir/build.log" 2>&1
  build_status=$?
  set -e

  if [[ "$state" == unpatched ]]; then
    [[ $build_status -ne 0 ]] || {
      echo "error: unpatched template record regression unexpectedly compiled at -O$optimization" >&2
      exit 1
    }
    grep -Eiq 'missing.*;|aspect.*requires|declaration expected' "$case_dir/build.log" || {
      cat "$case_dir/build.log"
      exit 1
    }
    echo "cxx-ada-template-record-termination -O$optimization: expected rejection (GCC $version)"
    continue
  fi

  [[ $build_status -eq 0 ]] || {
    cat "$case_dir/build.log"
    exit 1
  }
  count=$(grep -Fc "with Convention => C_Pass_By_Copy;" "$spec")
  [[ $count -eq 7 ]] || {
    echo "error: expected 7 terminated template records, found $count" >&2
    exit 1
  }
  echo "cxx-ada-template-record-termination -O$optimization: patched (GCC $version)"
done
