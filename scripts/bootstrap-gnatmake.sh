#!/usr/bin/env bash
set -euo pipefail

: "${GNAT_PATCHES_REAL_GNATMAKE:?missing real gnatmake path}"
[[ -x "$GNAT_PATCHES_REAL_GNATMAKE" ]] || {
  echo "error: real gnatmake is not executable" >&2
  exit 1
}

"$GNAT_PATCHES_REAL_GNATMAKE" "$@" -margs -largs -static-libgcc
