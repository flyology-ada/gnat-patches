#!/usr/bin/env bash
set -euo pipefail

# A dark package mirror stalls apt-get update rather than failing it, and this
# repository builds compilers: an unbounded stall is indistinguishable from slow
# but legitimate progress. Bound every attempt so a hung mirror is reported as a
# retryable failure, and retry a fixed number of times before giving up.
#
# The bound exists to catch a mirror that has stopped responding, not one that is
# merely slow. A healthy update finishes in seconds, but a degraded mirror can
# still be transferring indexes minutes later, so the per-attempt budget is set
# far above the healthy case: 120s was observed cutting off an update that was
# downloading normally. Every attempt plus its delay has to fit inside the
# calling step's timeout-minutes alongside the install that follows.
attempts=${APT_UPDATE_ATTEMPTS:-3}
attempt_seconds=${APT_UPDATE_TIMEOUT:-300}
delay=${APT_UPDATE_DELAY:-15}

attempt=1
while :; do
  status=0
  sudo timeout "$attempt_seconds" apt-get update || status=$?
  if [[ "$status" -eq 0 ]]; then
    exit 0
  fi
  if [[ "$status" -eq 124 ]]; then
    reason="stalled past ${attempt_seconds}s"
  else
    reason="failed with status $status"
  fi
  if [[ "$attempt" -ge "$attempts" ]]; then
    echo "error: apt-get update $reason on attempt $attempt of $attempts" >&2
    exit 1
  fi
  echo "warning: apt-get update $reason on attempt $attempt of $attempts;" \
    "retrying in ${delay}s" >&2
  sleep "$delay"
  attempt=$((attempt + 1))
done
