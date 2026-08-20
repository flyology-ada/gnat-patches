#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT GCC_VERSION unpatched|patched" >&2
  exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
source "$root/scripts/regression-common.sh"
resolve_regression_toolchain "$1"
version=$2
state=$3
[[ "$state" == unpatched || "$state" == patched ]] || exit 2
gxx="$REGRESSION_TOOLCHAIN/bin/g++"
case_root="$root/panels/cxx-ada-spec/cases/recursive-secondary-base"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-recursive-mi.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  dir="$work/O$optimization"
  mkdir -p "$dir"
  cp "$case_root/recursive_secondary_base.C" \
    "$case_root/recursive_secondary_base_consumer.adb" "$dir/"
  (
    cd "$dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" \
      -fdump-ada-spec-slim recursive_secondary_base.C
  )

  if [[ "$state" == unpatched ]]; then
    set +e
    (cd "$dir"; "${REGRESSION_ENV[@]}" "$REGRESSION_GCC" \
      -c recursive_secondary_base_c.ads) >"$dir/build.log" 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]] || {
      echo "error: unpatched recursive concrete MI binding compiled" >&2
      exit 1
    }
    grep -Eiq 'must be an interface' "$dir/build.log"
    echo "cxx-ada recursive secondary-base panel -O$optimization: expected invalid MI (GCC $version)"
  else
    grep -F "type Most is limited new Primary with record" "$dir/recursive_secondary_base_c.ads"
    grep -F "field_2 : aliased Secondary;" "$dir/recursive_secondary_base_c.ads"
    grep -F "type Secondary is limited new Root with record" "$dir/recursive_secondary_base_c.ads"
    grep -F "field_2 : aliased Extra_As_Base;" "$dir/recursive_secondary_base_c.ads"
    (
      cd "$dir"
      "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f \
        "-O$optimization" recursive_secondary_base_consumer.adb \
        -largs recursive_secondary_base.o -lstdc++
      "${REGRESSION_ENV[@]}" ./recursive_secondary_base_consumer
    ) >"$dir/output.log" 2>&1 || { cat "$dir/output.log"; exit 1; }
    grep -Fx "MATCH recursive concrete secondary bases" "$dir/output.log"
    echo "cxx-ada recursive secondary-base panel -O$optimization: patched (GCC $version)"
  fi
done
