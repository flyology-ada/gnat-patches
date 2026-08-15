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

case_root="$root/panels/cxx-ada-spec/cases/core-language"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-core-panel.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$case_root/panel_api.C" "$case_root/panel_core.adb" \
    "$case_root/panel_core_namespaced.adb" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" -fdump-ada-spec-slim panel_api.C
    consumer=panel_core.adb
    if grep -Fq "package Class_bridge_panel_Base" panel_api_c.ads; then
      consumer=panel_core_namespaced.adb
    fi
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f "-O$optimization" \
      "$consumer" -largs panel_api.o -lstdc++
    "${REGRESSION_ENV[@]}" "./${consumer%.adb}"
  )
  echo "cxx-ada core-language panel -O$optimization: PASS (GCC $version)"
done
