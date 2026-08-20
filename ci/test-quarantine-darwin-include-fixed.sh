#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/darwin-include-fixed-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

mkdir -p \
  "$test_dir/toolchain/lib/gcc/aarch64-apple-darwin/13.2.0/include-fixed" \
  "$test_dir/toolchain/lib/gcc/aarch64-apple-darwin/13.2.0/alt/include-fixed"
printf 'sdk header\n' \
  >"$test_dir/toolchain/lib/gcc/aarch64-apple-darwin/13.2.0/include-fixed/stdio.h"

count=$("$root/scripts/quarantine-darwin-include-fixed.sh" \
  "$test_dir/toolchain" build-sdk)
[[ $count == 2 ]]
[[ ! -e "$test_dir/toolchain/lib/gcc/aarch64-apple-darwin/13.2.0/include-fixed" ]]
[[ -f "$test_dir/toolchain/lib/gcc/aarch64-apple-darwin/13.2.0/include-fixed.build-sdk/stdio.h" ]]
[[ -d "$test_dir/toolchain/lib/gcc/aarch64-apple-darwin/13.2.0/alt/include-fixed.build-sdk" ]]

if "$root/scripts/quarantine-darwin-include-fixed.sh" \
  "$test_dir/toolchain" build-sdk >/dev/null 2>&1; then
  echo "error: quarantine accepted a toolchain without include-fixed" >&2
  exit 1
fi

echo "Darwin include-fixed quarantine test: PASS"
