#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/homebrew-gxx-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin" "$test_dir/prefix/bin"
printf '%s\n' '#!/usr/bin/env bash' \
  'case $1 in' \
  '  --prefix) printf "%s\n" "$TEST_BREW_PREFIX" ;;' \
  '  list) printf "%s\n" "gcc 15.2.0" ;;' \
  '  *) exit 2 ;;' \
  'esac' >"$test_dir/bin/brew"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' \
  >"$test_dir/prefix/bin/g++-15"
chmod +x "$test_dir/bin/brew" "$test_dir/prefix/bin/g++-15"

actual=$(PATH="$test_dir/bin:$PATH" TEST_BREW_PREFIX=$test_dir/prefix \
  "$root/scripts/homebrew-gxx.sh")
[[ "$actual" == "$test_dir/prefix/bin/g++-15" ]]

rm "$test_dir/prefix/bin/g++-15"
if PATH="$test_dir/bin:$PATH" TEST_BREW_PREFIX=$test_dir/prefix \
  "$root/scripts/homebrew-gxx.sh" >/dev/null 2>&1; then
  echo "error: missing versioned Homebrew g++ was accepted" >&2
  exit 1
fi

echo "Homebrew GNU g++ selection: PASS"
