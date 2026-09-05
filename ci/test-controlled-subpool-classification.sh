#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/controlled-subpool-classification.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/toolchain/bin"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  "printf '%s\\n' '#!/usr/bin/env bash' 'echo \"PASS controlled named subpool allocator\"' >controlled_subpool_allocator" \
  'chmod +x controlled_subpool_allocator' \
  >"$test_dir/toolchain/bin/gnatmake"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' \
  >"$test_dir/toolchain/bin/gcc"
chmod +x "$test_dir/toolchain/bin/gnatmake" "$test_dir/toolchain/bin/gcc"

known_good=$(
  "$root/bundles/controlled-subpool-allocator/run-test.sh" \
    "$test_dir/toolchain" 15.3.0 patched
)
[[ $(printf '%s\n' "$known_good" | grep -cF ': known-good-control ') -eq 2 ]]
if printf '%s\n' "$known_good" | grep -Fq ': patched '; then
  echo "error: known-good release was labeled patched" >&2
  exit 1
fi

affected=$(
  "$root/bundles/controlled-subpool-allocator/run-test.sh" \
    "$test_dir/toolchain" 15.1.0 patched
)
[[ $(printf '%s\n' "$affected" | grep -cF ': patched ') -eq 2 ]]

echo "controlled-subpool classification: PASS"
