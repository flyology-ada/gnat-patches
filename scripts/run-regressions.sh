#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT EXPECTED_RESULT(control|fail|patched)" >&2
  exit 2
fi

toolchain=$1
if [[ -d "$toolchain" ]]; then
  toolchain=$(cd "$toolchain" && pwd)
fi
expected=$2
[[ "$expected" == control || "$expected" == fail || "$expected" == patched ]] || {
  echo "error: expected result must be control, fail, or patched" >&2
  exit 2
}
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture="$root/bundles/storage-model-actuals/tests/storage_model_actuals.adb"
gnatmake="$toolchain/bin/gnatmake"
[[ -x "$gnatmake" ]] || gnatmake=$(command -v gnatmake-13 || true)
[[ -x "$gnatmake" ]] || { echo "error: no gnatmake in $toolchain" >&2; exit 1; }
runtime_env=(env)
if [[ $(uname -s) == Darwin && -d "$toolchain/lib" ]]; then
  runtime_env+=("DYLD_LIBRARY_PATH=$toolchain/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}")
  runtime_env+=("LD_LIBRARY_PATH=$toolchain/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}")
  runtime_env+=("LD_RUN_PATH=$toolchain/lib${LD_RUN_PATH:+:$LD_RUN_PATH}")
elif [[ -d "$toolchain/lib64" ]]; then
  runtime_env+=("LIBRARY_PATH=$toolchain/lib64${LIBRARY_PATH:+:$LIBRARY_PATH}")
  runtime_env+=("LD_LIBRARY_PATH=$toolchain/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}")
  runtime_env+=("LD_RUN_PATH=$toolchain/lib64${LD_RUN_PATH:+:$LD_RUN_PATH}")
elif [[ -d "$toolchain/lib" ]]; then
  runtime_env+=("LIBRARY_PATH=$toolchain/lib${LIBRARY_PATH:+:$LIBRARY_PATH}")
  runtime_env+=("LD_LIBRARY_PATH=$toolchain/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}")
  runtime_env+=("LD_RUN_PATH=$toolchain/lib${LD_RUN_PATH:+:$LD_RUN_PATH}")
fi
work=$(mktemp -d "${TMPDIR:-/tmp}/gnat-patches-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

for optimization in 0 2; do
  case_dir="$work/O$optimization"
  mkdir -p "$case_dir"
  cp "$fixture" "$case_dir/storage_model_actuals.adb"
  (
    cd "$case_dir"
    "${runtime_env[@]}" "$gnatmake" -q -gnatX0 -gnata "-O$optimization" storage_model_actuals.adb
  )
  set +e
  "${runtime_env[@]}" "$case_dir/storage_model_actuals" >"$case_dir/output.log" 2>&1
  status=$?
  set -e
  if [[ "$expected" == control || "$expected" == patched ]]; then
    [[ $status -eq 0 ]] || { cat "$case_dir/output.log"; exit 1; }
    if [[ "$expected" == control ]]; then
      grep -F "PASS reads= 15 writes= 8 read_bytes= 92 write_bytes= 80" "$case_dir/output.log"
    else
      grep -F "PASS reads= 16 writes= 8 read_bytes= 100 write_bytes= 80" "$case_dir/output.log"
    fi
  else
    [[ $status -ne 0 ]] || { echo "error: unpatched control unexpectedly passed at -O$optimization"; exit 1; }
    grep -Eiq 'CONSTRAINT_ERROR|erroneous memory access' "$case_dir/output.log" || {
      cat "$case_dir/output.log"; exit 1;
    }
  fi
  echo "regression -O$optimization: $expected"
done
