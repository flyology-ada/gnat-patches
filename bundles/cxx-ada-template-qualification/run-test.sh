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

cxx_fixture="$root/bundles/cxx-ada-template-qualification/tests/template_instantiation_qualification.C"
ada_fixture="$root/bundles/cxx-ada-template-qualification/tests/template_instantiation_qualification.adb"
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-cxx-ada-template-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$cxx_fixture" "$ada_fixture" "$case_dir/"
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$gxx" -c "-O$optimization" -fdump-ada-spec-slim template_instantiation_qualification.C
  )

  spec="$case_dir/template_instantiation_qualification_c.ads"
  [[ -f "$spec" ]] || {
    echo "error: g++ did not generate $spec" >&2
    exit 1
  }

  set +e
  (
    cd "$case_dir"
    "${REGRESSION_ENV[@]}" "$REGRESSION_GNATMAKE" -q -f "-O$optimization" template_instantiation_qualification.adb
  ) >"$case_dir/build.log" 2>&1
  build_status=$?
  set -e

  if [[ "$state" == unpatched ]]; then
    [[ $build_status -ne 0 ]] || {
      echo "error: unpatched C++ Ada template regression unexpectedly compiled at -O$optimization" >&2
      exit 1
    }
    grep -Eiq 'Box.*not visible|multiple use clauses cause hiding' "$case_dir/build.log" || {
      cat "$case_dir/build.log"
      exit 1
    }
    echo "cxx-ada-template-qualification -O$optimization: expected ambiguous type rejection (GCC $version)"
    continue
  fi

  [[ $build_status -eq 0 ]] || {
    cat "$case_dir/build.log"
    exit 1
  }
  grep -F "subtype Int_Box is Box_int.Box;" "$spec"
  grep -F "subtype Double_Box is Box_double.Box;" "$spec"
  grep -F "item : aliased Box_int.Box;" "$spec"
  grep -F "function identity (value : Box_double.Box) return Box_double.Box" "$spec"
  grep -F "subtype Alias_Int_Box is Box_int.Box;" "$spec"
  if grep -Fq "function New_Alias_Box" "$spec"; then
    grep -F "function New_Alias_Box return Alias_Box;" "$spec"
  fi
  "${REGRESSION_ENV[@]}" "$case_dir/template_instantiation_qualification" >"$case_dir/output.log" 2>&1 || {
    cat "$case_dir/output.log"
    exit 1
  }
  grep -F "PASS C++ Ada template qualification" "$case_dir/output.log"
  echo "cxx-ada-template-qualification -O$optimization: patched (GCC $version)"
done
