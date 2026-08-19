#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT GCC_VERSION unpatched|patched|staged" >&2
  exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
toolchain=$1
version=$2
state=$3
case "$state" in
  unpatched|patched|staged) ;;
  *)
    echo "error: state must be unpatched, patched, or staged" >&2
    exit 2
    ;;
esac

# A staged compiler carries patchset 1.2.0 plus the staged bundles, so every
# bundle runner it selects expects patched behavior.
bundle_state=$state
[[ "$state" != staged ]] || bundle_state=patched

"$root/panels/cxx-ada-spec/cases/core-language/run-test.sh" "$toolchain" "$version"
"$root/panels/cxx-ada-spec/cases/abi-layout/run-test.sh" "$toolchain" "$version"
"$root/panels/cxx-ada-spec/cases/call-abi/run-test.sh" "$toolchain" "$version"
"$root/panels/cxx-ada-spec/cases/interface-secondary-base/run-test.sh" \
  "$toolchain" "$version"
"$root/panels/cxx-ada-spec/cases/exception-interoperability/run-test.sh" \
  "$toolchain" "$version"
"$root/panels/cxx-ada-spec/cases/uninstantiated-templates/run-test.sh" \
  "$toolchain" "$version"
"$root/panels/cxx-ada-spec/cases/stdlib-value-facade/run-test.sh" \
  "$toolchain" "$version"

# Bundles accepted into patchset 1.2.0.
"$root/bundles/cxx-ada-template-qualification/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-template-record-termination/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-explicit-alignment/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-namespace-identity/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-qualified-method-names/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-casefold-identity/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-template-nested-types/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-anonymous-enums/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-char8-type/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-int128-types/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-vector-types/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-member-pointers/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-inherited-tail-padding/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-empty-class-storage/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-enclosing-type-method-names/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-profile-formal-type-names/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"
"$root/bundles/cxx-ada-visible-type-method-names/run-test.sh" \
  "$toolchain" "$version" "$bundle_state"

# Suites whose subject is a staged bundle. Patchset 1.2.0 does not ship those
# bundles, so a patched-only compiler is not asked to satisfy them and the
# panel makes no claim about them in that state.
if [[ "$state" == patched ]]; then
  echo "staged C++ Ada suites: SKIP 6 suites (not in patchset 1.2.0, GCC $version)"
else
  "$root/panels/cxx-ada-spec/cases/recursive-secondary-base/run-test.sh" \
    "$toolchain" "$version" "$bundle_state"
  "$root/bundles/cxx-ada-virtual-inheritance-layout/run-test.sh" \
    "$toolchain" "$version" "$bundle_state"
  "$root/bundles/cxx-ada-virtual-diamond-layout/run-test.sh" \
    "$toolchain" "$version" "$bundle_state"
  "$root/bundles/cxx-ada-concrete-multiple-inheritance/run-test.sh" \
    "$toolchain" "$version" "$bundle_state"
  "$root/bundles/cxx-ada-derived-virtual-slots/run-test.sh" \
    "$toolchain" "$version" "$bundle_state"
  "$root/bundles/cxx-ada-generated-name-identity/run-test.sh" \
    "$toolchain" "$version" "$bundle_state"
fi

"$root/panels/cxx-ada-spec/generated/run-test.sh" "$toolchain" "$version" "$state"

echo "C++ Ada feature panel: PASS GCC $version ($state)"
