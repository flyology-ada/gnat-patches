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

case_root="$root/panels/cxx-ada-spec/cases/interface-secondary-base"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-interface-panel.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$case_root/interface_secondary_base.C" \
    "$case_root/interface_secondary_base_consumer.adb" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" \
      -fdump-ada-spec-slim interface_secondary_base.C
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
      "-O$optimization" interface_secondary_base_consumer.adb \
      -largs interface_secondary_base.o -lstdc++
    "${REGRESSION_ENV[@]}" ./interface_secondary_base_consumer
  )
  echo "cxx-ada interface-secondary-base panel -O$optimization: PASS (GCC $version)"
done
