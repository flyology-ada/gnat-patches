#!/usr/bin/env bash
set -euo pipefail

command -v brew >/dev/null 2>&1 || {
  echo "error: Homebrew is required for the Darwin host C++ fallback" >&2
  exit 1
}

prefix=$(brew --prefix gcc)
formula=$(brew list --versions gcc)
version=${formula#gcc }
[[ -n "$version" && "$version" != "$formula" && "$version" != *' '* ]] || {
  echo "error: cannot resolve the installed Homebrew GCC version" >&2
  exit 1
}
major=${version%%.*}
host_cxx=$prefix/bin/g++-$major
[[ -x "$host_cxx" ]] || {
  echo "error: Homebrew GNU g++ is not executable: $host_cxx" >&2
  exit 1
}

printf '%s\n' "$host_cxx"
