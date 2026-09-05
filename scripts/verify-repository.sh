#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

python3 scripts/manifest.py validate
ci/test-bootstrap-gnatmake.sh
ci/test-controlled-subpool-classification.sh
ci/test-generate-alire-index.sh
ci/test-generate-site.sh
ci/test-homebrew-gxx.sh
ci/test-quarantine-darwin-include-fixed.sh
ci/test-workflow-action-pins.sh
scripts/check-workflow-action-pins.sh

if find . -type f \( -name '*.orig' -o -name '*.rej' \) -print -quit | grep -q .; then
  echo "error: patch residue is present" >&2
  exit 1
fi

for script in scripts/*.sh scripts/*.py ci/*.sh; do
  [[ -e "$script" ]] || continue
  if [[ ! -x "$script" ]]; then
    echo "error: $script is not executable" >&2
    exit 1
  fi
done

while IFS= read -r script; do
  if [[ ! -x "$script" ]]; then
    echo "error: $script is not executable" >&2
    exit 1
  fi
done < <(find panels -type f \( -name '*.sh' -o -name '*.py' \) -print)

PYTHONDONTWRITEBYTECODE=1 python3 panels/cxx-ada-spec/generated/coverage.py

archive_test=$(mktemp -d "${TMPDIR:-/tmp}/gnat-patches-archive-test.XXXXXX")
trap 'rm -rf "$archive_test"' EXIT
mkdir -p "$archive_test/source/bin" "$archive_test/source/lib"
printf '#!/bin/sh\n' >"$archive_test/source/bin/gnatmake"
printf 'fixture\n' >"$archive_test/source/lib/libgnat.a"
scripts/deterministic-archive.py "$archive_test/source" \
  "$archive_test/toolchain.tar.gz" gnat_flyology_native-test
[[ $(scripts/verify-alire-archive.py "$archive_test/toolchain.tar.gz") == \
  gnat_flyology_native-test ]]
scripts/deterministic-archive.py "$archive_test/source" \
  "$archive_test/flat.tar.gz"
if scripts/verify-alire-archive.py "$archive_test/flat.tar.gz" >/dev/null 2>&1; then
  echo "error: flat Alire archive was accepted" >&2
  exit 1
fi

echo "repository verification: PASS"
