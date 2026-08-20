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
major=${version%%.*}
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

cxx_fixture="$root/bundles/cxx-ada-int128-types/tests/int128-types.C"
ada_fixture="$root/bundles/cxx-ada-int128-types/tests/int128_types_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-int128-types.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$cxx_fixture" "$ada_fixture" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" \
      -fdump-ada-spec-slim int128-types.C
  )

  spec="$case_dir/int128_types_c.ads"
  [[ -f "$spec" ]] || {
    echo "error: g++ did not generate $spec" >&2
    exit 1
  }

  set +e
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" int128_types_consumer.adb \
      -largs int128-types.o -lstdc++
    "${REGRESSION_ENV[@]}" ./int128_types_consumer
  ) >"$case_dir/run.log" 2>&1
  run_status=$?
  set -e

  if [[ "$state" == unpatched && ( "$major" == 13 || "$major" == 14 ) ]]; then
    [[ $run_status -ne 0 ]] || {
      echo "error: unpatched __int128 regression unexpectedly passed" >&2
      exit 1
    }
    grep -Eiq 'uu_int128_unsigned.*undefined' "$case_dir/run.log" || {
      cat "$case_dir/run.log"
      exit 1
    }
    echo "cxx-ada-int128-types -O$optimization: expected undefined unsigned type (GCC $version)"
    continue
  fi

  [[ $run_status -eq 0 ]] || {
    cat "$case_dir/run.log"
    exit 1
  }
  grep -Eq 'Extensions\.Signed_128' "$spec"
  grep -Eq 'Extensions\.Unsigned_128' "$spec"
  echo "cxx-ada-int128-types -O$optimization: supported (GCC $version, $state)"
done
