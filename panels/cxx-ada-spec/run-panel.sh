#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT GCC_VERSION unpatched|patched" >&2
  exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
toolchain=$1
version=$2
state=$3
[[ "$state" == unpatched || "$state" == patched ]] || {
  echo "error: state must be unpatched or patched" >&2
  exit 2
}

"$root/panels/cxx-ada-spec/cases/core-language/run-test.sh" "$toolchain" "$version"
"$root/panels/cxx-ada-spec/cases/abi-layout/run-test.sh" "$toolchain" "$version"
"$root/panels/cxx-ada-spec/cases/call-abi/run-test.sh" "$toolchain" "$version"
"$root/panels/cxx-ada-spec/cases/interface-secondary-base/run-test.sh" "$toolchain" "$version"
"$root/bundles/cxx-ada-template-qualification/run-test.sh" "$toolchain" "$version" "$state"
"$root/bundles/cxx-ada-template-record-termination/run-test.sh" \
  "$toolchain" "$version" "$state"
"$root/bundles/cxx-ada-explicit-alignment/run-test.sh" \
  "$toolchain" "$version" "$state"
"$root/bundles/cxx-ada-namespace-identity/run-test.sh" \
  "$toolchain" "$version" "$state"
"$root/panels/cxx-ada-spec/cases/known-defects/run-test.sh" "$toolchain" "$version"
"$root/panels/cxx-ada-spec/generated/run-test.sh" "$toolchain" "$version" "$state"

echo "C++ Ada feature panel: PASS GCC $version ($state)"
