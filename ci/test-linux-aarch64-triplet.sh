#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

[[ $("$root/scripts/linux-aarch64-triplet.sh" aarch64) == aarch64-linux-gnu ]]
[[ $("$root/scripts/linux-aarch64-triplet.sh" arm64) == aarch64-linux-gnu ]]
if "$root/scripts/linux-aarch64-triplet.sh" x86_64 >/dev/null 2>&1; then
  echo "error: unsupported Linux architecture was accepted" >&2
  exit 1
fi

echo "Linux AArch64 triplet selection: PASS"
