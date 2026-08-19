#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/apt-get-update-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin"
printf '%s\n' '#!/usr/bin/env bash' 'exec "$@"' >"$test_dir/bin/sudo"
printf '%s\n' '#!/usr/bin/env bash' 'shift' 'exec "$@"' >"$test_dir/bin/timeout"
printf '%s\n' '#!/usr/bin/env bash' \
  'count=$(( $(cat "$TEST_APT_COUNT") + 1 ))' \
  'printf "%s\n" "$count" >"$TEST_APT_COUNT"' \
  '[[ "$count" -gt "$TEST_APT_FAILURES" ]]' >"$test_dir/bin/apt-get"
chmod +x "$test_dir/bin/sudo" "$test_dir/bin/timeout" "$test_dir/bin/apt-get"

run_update() {
  printf '0\n' >"$test_dir/count"
  PATH="$test_dir/bin:$PATH" TEST_APT_COUNT=$test_dir/count \
    TEST_APT_FAILURES=$1 APT_UPDATE_DELAY=0 \
    "$root/ci/apt-get-update.sh"
}

run_update 0 >/dev/null
[[ $(cat "$test_dir/count") == 1 ]]

run_update 2 >/dev/null
[[ $(cat "$test_dir/count") == 3 ]]

if run_update 3 >/dev/null 2>&1; then
  echo "error: an unreachable package mirror was accepted" >&2
  exit 1
fi
[[ $(cat "$test_dir/count") == 3 ]]

printf '%s\n' '#!/usr/bin/env bash' 'exit 124' >"$test_dir/bin/timeout"
chmod +x "$test_dir/bin/timeout"
printf '0\n' >"$test_dir/count"
stalled=$(PATH="$test_dir/bin:$PATH" TEST_APT_COUNT=$test_dir/count \
  TEST_APT_FAILURES=0 APT_UPDATE_DELAY=0 APT_UPDATE_TIMEOUT=7 \
  "$root/ci/apt-get-update.sh" 2>&1 || true)
grep -q 'stalled past 7s' <<<"$stalled"

echo "apt-get update retry bound: PASS"
