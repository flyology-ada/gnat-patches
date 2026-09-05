#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  set -- .github/workflows
fi

uses_pattern='^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]+[^#[:space:]]+'

set +e
matches=$(grep -R -H -n -E "$uses_pattern" "$@" 2>&1)
grep_status=$?
set -e

case $grep_status in
  0) ;;
  1) exit 0 ;;
  *)
    printf '%s\n' "$matches" >&2
    echo "error: unable to inspect GitHub Action references" >&2
    exit "$grep_status"
    ;;
esac

violation=false
while IFS= read -r match; do
  ref=${match#*uses:}
  ref=${ref#"${ref%%[![:space:]]*}"}
  ref=${ref%%[[:space:]]*}
  case $ref in
    \"*\") ref=${ref:1:${#ref}-2} ;;
    \'*\') ref=${ref:1:${#ref}-2} ;;
  esac

  if [[ $ref == ./* ]] || [[ $ref == docker://* ]] ||
    [[ $ref =~ ^[^#[:space:]@]+/[^#[:space:]@]+@[[:xdigit:]]{40}$ ]]; then
    continue
  fi

  printf '%s\n' "$match"
  violation=true
done <<<"$matches"

if [[ $violation == true ]]; then
  echo "error: external GitHub Actions must use full 40-hex commit SHAs" >&2
  exit 1
fi
