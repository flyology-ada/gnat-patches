#!/usr/bin/env bash
set -euo pipefail

build_dir=${1:-build}
output=${2:-logs}
mkdir -p "$output"
if [[ -d "$build_dir" ]]; then
  find "$build_dir" -type f \( -name config.log -o -name '*.sum' -o -name '*.log' \) -print >"$output/files.txt"
  if [[ -s "$output/files.txt" ]]; then
    tar -czf "$output/build-logs.tar.gz" -T "$output/files.txt"
  fi
fi
df -h >"$output/disk.txt"
