#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT GCC_VERSION" >&2
  exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
source "$root/scripts/regression-common.sh"
resolve_regression_toolchain "$1"

PYTHONDONTWRITEBYTECODE=1 python3 \
  "$root/panels/cxx-ada-spec/generated/coverage.py"
"${REGRESSION_ENV[@]}" python3 \
  "$root/panels/cxx-ada-spec/generated/pairwise.py" \
  "$REGRESSION_TOOLCHAIN" "$2"
"${REGRESSION_ENV[@]}" python3 \
  "$root/panels/cxx-ada-spec/generated/catalog.py" \
  "$REGRESSION_TOOLCHAIN" "$2"
"${REGRESSION_ENV[@]}" python3 \
  "$root/panels/cxx-ada-spec/generated/grammar.py" \
  "$REGRESSION_TOOLCHAIN" "$2"
