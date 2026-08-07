#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

python3 scripts/manifest.py validate

if rg --hidden -n 'uses: [^#[:space:]]+@(v[0-9]+|main|master)([[:space:]]|$)' .github/workflows; then
  echo "error: GitHub Actions must use immutable commit SHAs" >&2
  exit 1
fi

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

echo "repository verification: PASS"
