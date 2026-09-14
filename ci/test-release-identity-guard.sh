#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/release-identity-guard.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

cat >"$test_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
endpoint=${@: -1}
printf '%s\n' "$endpoint" >>"$MOCK_GH_LOG"

case "$MOCK_GH_MODE:$endpoint" in
  absent:*)
    printf 'HTTP/2.0 404 Not Found\n' >&2
    exit 1
    ;;
  release-exists:*releases/tags/*|tag-exists:*git/ref/tags/*)
    printf 'HTTP/2.0 200 OK\n'
    exit 0
    ;;
  release-exists:*|tag-exists:*)
    printf 'HTTP/2.0 404 Not Found\n' >&2
    exit 1
    ;;
  unauthorized:*)
    printf 'HTTP/2.0 401 Unauthorized\n' >&2
    exit 1
    ;;
  rate-limited:*)
    printf 'HTTP/2.0 403 Forbidden\n' >&2
    exit 1
    ;;
  network:*)
    printf 'network unavailable\n' >&2
    exit 1
    ;;
esac
EOF
chmod +x "$test_dir/gh"

guard="$root/scripts/check-release-identity-available.sh"
tag=patchset-1.1.1-gcc-16.2.0
export MOCK_GH_LOG="$test_dir/calls"
export PATH="$test_dir:$PATH"

MOCK_GH_MODE=absent "$guard" flyology-ada/gnat-patches "$tag" >/dev/null
[[ $(wc -l <"$MOCK_GH_LOG") -eq 2 ]]

for mode in release-exists tag-exists unauthorized rate-limited network; do
  : >"$MOCK_GH_LOG"
  if MOCK_GH_MODE=$mode "$guard" flyology-ada/gnat-patches "$tag" >/dev/null 2>&1; then
    echo "error: release identity guard accepted $mode" >&2
    exit 1
  fi
done

echo "release identity fail-closed guard: PASS"
