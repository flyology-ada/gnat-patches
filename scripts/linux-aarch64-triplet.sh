#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "usage: $0 [ARCH]" >&2
  exit 2
fi

arch=${1:-$(uname -m)}
case "$arch" in
  arm64|aarch64) printf '%s\n' aarch64-linux-gnu ;;
  *)
    echo "error: unsupported Linux native architecture: $arch" >&2
    exit 1
    ;;
esac
