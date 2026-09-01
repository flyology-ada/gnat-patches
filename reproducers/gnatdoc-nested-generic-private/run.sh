#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
prefix="$root/.alire-prefix"
gnatdoc="$prefix/bin/gnatdoc"

mkdir -p "$root/.work"
work=$(mktemp -d "$root/.work/run.XXXXXX")
trap 'rm -rf "$work"' EXIT

if [[ ! -x "$gnatdoc" ]]; then
  alr install --prefix="$prefix" gnatdoc_bin=26.0.0
fi

set +e
version=$("$gnatdoc" --version 2>&1)
set -e
[[ "$version" == "GNATdoc 26.0.0 (20260415)" ]] || {
  echo "error: expected GNATdoc 26.0.0 (20260415), got: $version" >&2
  exit 1
}

cd "$root"
mkdir -p "$work/obj"
alr exec -- gprbuild -q -f -P reproducer.gpr \
  -XBUILD_DIR="$work/obj"

set +e
output=$(alr exec -- "$gnatdoc" \
  --backend html --warnings --style leading --generate public \
  -P reproducer.gpr -XBUILD_DIR="$work/obj" -O "$work/html" 2>&1)
status=$?
set -e

printf '%s\n' "$output"

if ! grep -Fq 'p.ads:3:4: internal error:' <<<"$output" ||
   ! grep -Fq 'raised GNATDOC.NOT_IMPLEMENTED : at gnatdoc-frontend.adb:909' \
     <<<"$output" ||
   ! grep -Fq '<GenericPackageDecl ["G"] p.ads:3:4-5:10>' <<<"$output"; then
  echo 'error: expected GNATdoc crash signature was not observed' >&2
  exit 1
fi

printf 'GNATdoc exit status: %s (the internal error currently exits zero)\n' \
  "$status"
printf 'Alire: %s\n' "$(alr --version)"
alr exec -- gnatmake --version | sed -n '1p'
alr exec -- gprbuild --version | sed -n '1p'
echo 'reproducer: PASS (expected GNATDOC.NOT_IMPLEMENTED observed)'
