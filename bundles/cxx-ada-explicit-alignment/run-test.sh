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

cxx_fixture="$root/bundles/cxx-ada-explicit-alignment/tests/explicit-alignment.C"
ada_fixture="$root/bundles/cxx-ada-explicit-alignment/tests/explicit_alignment_consumer.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-alignment-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$cxx_fixture" "$ada_fixture" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" \
      -fdump-ada-spec-slim explicit-alignment.C
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" explicit_alignment_consumer.adb \
      -largs explicit-alignment.o -lstdc++
    "${REGRESSION_ENV[@]}" ./explicit_alignment_consumer
  ) >"$case_dir/output.log" 2>&1 || {
    cat "$case_dir/output.log"
    exit 1
  }

  spec="$case_dir/explicit_alignment_c.ads"
  if [[ "$state" == unpatched ]]; then
    grep -F "MISMATCH C++ Ada explicit alignment" "$case_dir/output.log"
    if grep -Fq "Alignment => 32" "$spec"; then
      echo "error: unpatched mapper unexpectedly preserved explicit alignment" >&2
      exit 1
    fi
    echo "cxx-ada-explicit-alignment -O$optimization: expected mismatch (GCC $version)"
    continue
  fi

  grep -F "Alignment => 32" "$spec"
  grep -F "MATCH C++ Ada explicit alignment" "$case_dir/output.log"
  echo "cxx-ada-explicit-alignment -O$optimization: patched (GCC $version)"
done
