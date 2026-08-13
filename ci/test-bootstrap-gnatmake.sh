#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/gnatmake-wrapper-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$@" >"$TEST_LOG"' \
  >"$test_dir/gnatmake-success"
printf '%s\n' '#!/usr/bin/env bash' 'exit 7' >"$test_dir/gnatmake-failure"
chmod +x "$test_dir/gnatmake-success" "$test_dir/gnatmake-failure"

TEST_LOG=$test_dir/arguments \
GNAT_PATCHES_REAL_GNATMAKE=$test_dir/gnatmake-success \
  "$root/scripts/bootstrap-gnatmake.sh" example.adb -o 'example tool'
printf '%s\n' example.adb -o 'example tool' -margs -largs -static-libgcc \
  >"$test_dir/expected-arguments"
cmp "$test_dir/expected-arguments" "$test_dir/arguments"

set +e
GNAT_PATCHES_REAL_GNATMAKE=$test_dir/gnatmake-failure \
  "$root/scripts/bootstrap-gnatmake.sh" example.adb
status=$?
set -e
[[ $status -eq 7 ]]

echo "bootstrap gnatmake wrapper: PASS"
