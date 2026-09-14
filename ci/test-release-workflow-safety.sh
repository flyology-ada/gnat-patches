#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
release="$root/.github/workflows/release.yml"
validate="$root/.github/workflows/validate.yml"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/release-workflow-safety.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

awk '
  function indentation(line) {
    match(line, /[^ ]/)
    return RSTART ? RSTART - 1 : 999
  }
  {
    current = indentation($0)
    if (in_run && $0 !~ /^[ ]*$/ && current <= run_indent) {
      in_run = 0
    }
    if ($0 ~ /^[ ]*run:/) {
      in_run = 1
      run_indent = current
    }
    if (in_run && $0 ~ /\$\{\{[ ]*(inputs\.|needs\.release\.outputs\.)/) {
      print "unsafe workflow expression in shell source: " NR ":" $0 > "/dev/stderr"
      unsafe = 1
    }
  }
  END { exit unsafe ? 1 : 0 }
' "$release"

awk '
  /^      - name: Resolve source version$/ { wanted = 1; next }
  wanted && /^        run: \|$/ { capture = 1; next }
  capture && /^          / { sub(/^          /, ""); print; next }
  capture { exit }
' "$release" >"$test_dir/resolve-source-version.sh"
[[ -s "$test_dir/resolve-source-version.sh" ]]
grep -Fq '"$PATCHSET_VERSION" "$GCC_VERSION"' \
  "$test_dir/resolve-source-version.sh"

mkdir -p "$test_dir/scripts"
cat >"$test_dir/scripts/manifest.py" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$GCC_VERSION"
EOF
chmod +x "$test_dir/scripts/manifest.py"

sentinel="$test_dir/injected"
payload="16.2.0\"; touch \"$sentinel\"; #"
GITHUB_ENV="$test_dir/github-env" \
GITHUB_OUTPUT="$test_dir/github-output" \
PATCHSET_VERSION="$payload" \
GCC_VERSION="$payload" \
  bash -c 'cd "$1" && bash resolve-source-version.sh' _ "$test_dir"
[[ ! -e "$sentinel" ]]

grep -Fq 'name: failure-${{ matrix.patchset }}-gcc-${{ matrix.version }}-${{ matrix.platform }}' "$validate"
awk '
  /^          - \{patchset:/ {
    row = $0
    sub(/^.*patchset: /, "", row)
    split(row, fields, ", ")
    patchset = fields[1]
    version = fields[2]
    platform = fields[3]
    sub(/^version: /, "", version)
    sub(/^platform: /, "", platform)
    identity = patchset "-gcc-" version "-" platform
    if (seen[identity]++) {
      print "duplicate compiler matrix artifact identity: " identity > "/dev/stderr"
      duplicate = 1
    }
    count++
  }
  END {
    if (count != 18) {
      print "expected 18 compiler matrix rows, found " count > "/dev/stderr"
      exit 1
    }
    exit duplicate ? 1 : 0
  }
' "$validate"

echo "release workflow input and artifact safety: PASS"
