#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/workflow-action-pins-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

for mutable_ref in \
  actions/checkout@v4 \
  actions/setup-python@v6 \
  actions/checkout@v6.1.0 \
  actions/checkout@releases/v6 \
  actions/checkout@feature-branch \
  actions/checkout@d23441a; do
  printf '%s\n' \
    'steps:' \
    "  - uses: $mutable_ref" \
    >"$test_dir/mutable.yml"

  set +e
  "$root/scripts/check-workflow-action-pins.sh" \
    "$test_dir/mutable.yml" >/dev/null 2>&1
  status=$?
  set -e
  if [[ $status -ne 1 ]]; then
    echo "error: mutable GitHub Action ref was not rejected: $mutable_ref" >&2
    exit 1
  fi
done

printf '%s\n' \
  'steps:' \
  '  - uses: actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6' \
  '  - uses: actions/setup-python@ece7cb06caefa5fff74198d8649806c4678c61a1 # v6' \
  '  - uses: "actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803"' \
  '  - uses: ./local-action' \
  '  - uses: docker://alpine:3.22' \
  >"$test_dir/pinned.yml"

"$root/scripts/check-workflow-action-pins.sh" "$test_dir/pinned.yml"
"$root/scripts/check-workflow-action-pins.sh" \
  "$root/.github/workflows/agent-resources.yml"

set +e
"$root/scripts/check-workflow-action-pins.sh" \
  "$test_dir/nonexistent.yml" >/dev/null 2>&1
status=$?
set -e
if [[ $status -lt 2 ]]; then
  echo "error: workflow scan error was not propagated" >&2
  exit 1
fi

mkdir "$test_dir/no-grep-bin"
ln -s /bin/bash "$test_dir/no-grep-bin/bash"
set +e
PATH="$test_dir/no-grep-bin" "$root/scripts/check-workflow-action-pins.sh" \
  "$test_dir/pinned.yml" >/dev/null 2>&1
status=$?
set -e
if [[ $status -lt 2 ]]; then
  echo "error: missing workflow scanner was accepted" >&2
  exit 1
fi

mkdir "$test_dir/broken-grep-bin"
printf '%s\n' '#!/bin/sh' 'exit 2' >"$test_dir/broken-grep-bin/grep"
chmod +x "$test_dir/broken-grep-bin/grep"
set +e
PATH="$test_dir/broken-grep-bin:$PATH" \
  "$root/scripts/check-workflow-action-pins.sh" \
  "$test_dir/pinned.yml" >/dev/null 2>&1
status=$?
set -e
if [[ $status -lt 2 ]]; then
  echo "error: broken workflow scanner was accepted" >&2
  exit 1
fi

echo "workflow action pin check: PASS"
