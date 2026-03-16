#!/usr/bin/env bash
# Verify that a package version is available on pub.dev (with exponential backoff, max 10 min).
# Usage: verify-pubdev-package.sh <package_name> <expected_version>
# Exit 0 when version is available, 1 on timeout or invalid args.

set -euo pipefail

PACKAGE="${1:?Usage: $0 <package_name> <expected_version>}"
EXPECTED_VERSION="${2:?Usage: $0 <package_name> <expected_version>}"
MAX_WAIT_SEC=600
INITIAL_SLEEP=30
API_URL="https://pub.dev/api/packages/${PACKAGE}"

elapsed=0
sleep_sec=$INITIAL_SLEEP

echo "Checking pub.dev for ${PACKAGE}@${EXPECTED_VERSION} (max ${MAX_WAIT_SEC}s)..."

while [ $elapsed -lt $MAX_WAIT_SEC ]; do
  if resp=$(curl -sS -f "$API_URL" 2>/dev/null); then
    if echo "$resp" | grep -q "\"version\":\"${EXPECTED_VERSION}\""; then
      echo "Package ${PACKAGE}@${EXPECTED_VERSION} is available on pub.dev."
      exit 0
    fi
    # Also accept version in "versions" array
    if echo "$resp" | grep -q "\"${EXPECTED_VERSION}\""; then
      echo "Package ${PACKAGE} version ${EXPECTED_VERSION} is available on pub.dev."
      exit 0
    fi
  fi
  echo "  Not yet available (elapsed ${elapsed}s), waiting ${sleep_sec}s..."
  sleep "$sleep_sec"
  elapsed=$((elapsed + sleep_sec))
  # Exponential backoff: 30, 45, 60, 90, 120, 120, ...
  if [ $sleep_sec -lt 120 ]; then
    sleep_sec=$((sleep_sec + 15))
    [ $sleep_sec -gt 120 ] && sleep_sec=120
  fi
done

echo "ERROR: ${PACKAGE}@${EXPECTED_VERSION} not available on pub.dev after ${MAX_WAIT_SEC}s."
exit 1
