#!/usr/bin/env bash
set -euo pipefail

[[ ${CI:-} == true && $(uname -s) == Linux ]] || exit 0
for path in /usr/local/lib/android /usr/share/dotnet /opt/ghc; do
  [[ -e "$path" ]] || continue
  sudo rm -rf -- "$path"
done
df -h
