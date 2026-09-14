#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 OWNER/REPOSITORY RELEASE_TAG" >&2
  exit 2
fi

repository=$1
tag=$2
[[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
  echo "error: invalid GitHub repository: $repository" >&2
  exit 2
}
[[ "$tag" =~ ^patchset-[0-9]+\.[0-9]+\.[0-9]+-gcc-[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "error: invalid release tag: $tag" >&2
  exit 2
}

confirm_absent() {
  local kind=$1
  local endpoint=$2
  local response
  local status
  local result

  if response=$(gh api --include "$endpoint" 2>&1); then
    echo "error: $kind already exists: $tag" >&2
    return 1
  else
    result=$?
  fi

  status=$(printf '%s\n' "$response" | sed -nE \
    -e 's/^HTTP\/[^ ]+[[:space:]]+([0-9][0-9][0-9]).*/\1/p' \
    -e 's/.*\(HTTP ([0-9][0-9][0-9])\)$/\1/p' | tail -n 1)
  if [[ "$status" == 404 ]]; then
    return 0
  fi

  echo "error: unable to confirm that $kind is absent: $tag " \
    "(gh api exit $result, HTTP ${status:-unknown})" >&2
  return 1
}

confirm_absent release "repos/$repository/releases/tags/$tag"
confirm_absent tag "repos/$repository/git/ref/tags/$tag"
echo "release identity available: $tag"
