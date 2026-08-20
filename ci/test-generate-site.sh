#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python_bin=${PYTHON:-python3}

if ! "$python_bin" -c 'import tomllib' 2>/dev/null; then
  printf '%s must provide Python 3.11 or newer (tomllib is required)\n' "$python_bin" >&2
  exit 2
fi

cd "$root"
PYTHONDONTWRITEBYTECODE=1 "$python_bin" -m unittest discover -s tests
