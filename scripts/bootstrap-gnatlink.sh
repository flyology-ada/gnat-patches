#!/usr/bin/env bash
set -euo pipefail

: "${GNAT_PATCHES_REAL_GNATLINK:?missing real gnatlink path}"
: "${GNAT_PATCHES_BOOTSTRAP_LIBGCC:?missing bootstrap libgcc path}"
[[ -x "$GNAT_PATCHES_REAL_GNATLINK" ]] || {
  echo "error: real gnatlink is not executable" >&2
  exit 1
}
[[ -f "$GNAT_PATCHES_BOOTSTRAP_LIBGCC" ]] || {
  echo "error: bootstrap libgcc is not a file" >&2
  exit 1
}

"$GNAT_PATCHES_REAL_GNATLINK" "$@"
ln -sf "$GNAT_PATCHES_BOOTSTRAP_LIBGCC" \
  "$(basename "$GNAT_PATCHES_BOOTSTRAP_LIBGCC")"
