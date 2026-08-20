#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 TOOLCHAIN_ROOT LABEL" >&2
  exit 2
fi

toolchain=$(cd "$1" && pwd)
label=$2
case "$label" in
  bootstrap-sdk|build-sdk) ;;
  *) echo "error: unsupported include-fixed quarantine label: $label" >&2; exit 2 ;;
esac

fixed_count=0
while IFS= read -r -d '' fixed; do
  destination="$fixed.$label"
  [[ ! -e "$destination" ]] || {
    echo "error: include-fixed quarantine destination exists: $destination" >&2
    exit 1
  }
  mv "$fixed" "$destination"
  fixed_count=$((fixed_count + 1))
done < <(find "$toolchain/lib/gcc" -type d -name include-fixed -print0)

[[ $fixed_count -gt 0 ]] || {
  echo "error: Darwin toolchain has no SDK-derived include-fixed directory" >&2
  exit 1
}
printf '%s\n' "$fixed_count"
