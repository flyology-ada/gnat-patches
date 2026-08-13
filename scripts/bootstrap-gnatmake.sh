#!/usr/bin/env bash
set -euo pipefail

: "${GNAT_PATCHES_REAL_GNATMAKE:?missing real gnatmake path}"
: "${GNAT_PATCHES_BOOTSTRAP_LIBGCC:?missing bootstrap libgcc path}"
[[ -x "$GNAT_PATCHES_REAL_GNATMAKE" ]] || {
  echo "error: real gnatmake is not executable" >&2
  exit 1
}
[[ -f "$GNAT_PATCHES_BOOTSTRAP_LIBGCC" ]] || {
  echo "error: bootstrap libgcc is not a file" >&2
  exit 1
}

"$GNAT_PATCHES_REAL_GNATMAKE" "$@"
ln -sf "$GNAT_PATCHES_BOOTSTRAP_LIBGCC" \
  "$(basename "$GNAT_PATCHES_BOOTSTRAP_LIBGCC")"
