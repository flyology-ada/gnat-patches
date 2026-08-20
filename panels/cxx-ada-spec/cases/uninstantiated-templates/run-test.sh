#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then echo "usage: $0 TOOLCHAIN_ROOT GCC_VERSION" >&2; exit 2; fi
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
source "$root/scripts/regression-common.sh"
resolve_regression_toolchain "$1"
version=$2
gxx="$REGRESSION_TOOLCHAIN/bin/g++"
case_root="$root/panels/cxx-ada-spec/cases/uninstantiated-templates"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-uninstantiated.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  dir="$work/O$optimization"; mkdir -p "$dir"
  cp "$case_root/uninstantiated_templates.C" "$case_root/instantiated_templates.C" "$case_root/uninstantiated_templates_consumer.adb" "$dir/"
  (cd "$dir"; "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" -fdump-ada-spec-slim uninstantiated_templates.C; "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" -fdump-ada-spec-slim instantiated_templates.C)
  ! grep -Fq "Hidden" "$dir/uninstantiated_templates_c.ads"
  grep -F "package Hidden_int is" "$dir/instantiated_templates_c.ads"
  (cd "$dir"; "${REGRESSION_ENV[@]}" "$REGRESSION_GCC" -c instantiated_templates_c.ads; "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f "-O$optimization" uninstantiated_templates_consumer.adb -largs uninstantiated_templates.o -lstdc++; "${REGRESSION_ENV[@]}" ./uninstantiated_templates_consumer) >"$dir/output.log" 2>&1 || { cat "$dir/output.log"; exit 1; }
  grep -Fx "MATCH uninstantiated template boundary" "$dir/output.log"
  echo "cxx-ada uninstantiated-template boundary -O$optimization: PASS (GCC $version)"
done
