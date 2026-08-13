#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/gnatmake-wrapper-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/success" "$test_dir/failure"
printf 'bootstrap runtime\n' >"$test_dir/libgcc_s.1.1.dylib"

printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$@" >"$TEST_LOG"' \
  >"$test_dir/gnatmake-success"
printf '%s\n' '#!/usr/bin/env bash' 'exit 7' >"$test_dir/gnatmake-failure"
chmod +x "$test_dir/gnatmake-success" "$test_dir/gnatmake-failure"

(
  cd "$test_dir/success"
  TEST_LOG=$test_dir/arguments \
  GNAT_PATCHES_REAL_GNATMAKE=$test_dir/gnatmake-success \
  GNAT_PATCHES_BOOTSTRAP_LIBGCC=$test_dir/libgcc_s.1.1.dylib \
    "$root/scripts/bootstrap-gnatmake.sh" example.adb -o 'example tool'
)
printf '%s\n' example.adb -o 'example tool' >"$test_dir/expected-arguments"
cmp "$test_dir/expected-arguments" "$test_dir/arguments"
[[ -L "$test_dir/success/libgcc_s.1.1.dylib" ]]
[[ $(readlink "$test_dir/success/libgcc_s.1.1.dylib") == \
  "$test_dir/libgcc_s.1.1.dylib" ]]

set +e
(
  cd "$test_dir/failure"
  GNAT_PATCHES_REAL_GNATMAKE=$test_dir/gnatmake-failure \
  GNAT_PATCHES_BOOTSTRAP_LIBGCC=$test_dir/libgcc_s.1.1.dylib \
    "$root/scripts/bootstrap-gnatmake.sh" example.adb
)
status=$?
set -e
[[ $status -eq 7 ]]
[[ ! -e "$test_dir/failure/libgcc_s.1.1.dylib" ]]

echo "bootstrap gnatmake wrapper: PASS"
