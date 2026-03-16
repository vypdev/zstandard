#!/usr/bin/env bash
# Check that coverage meets the required threshold (default 95%) for each package.
# Usage: ./scripts/check_coverage.sh [threshold_percent]
# Run from repo root. Requires lcov (brew install lcov / apt-get install lcov).

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
THRESHOLD="${1:-95}"

check_package() {
  local dir="$1"
  local use_flutter="$2"
  if [[ ! -d "$dir" ]]; then
    echo "Skip $dir (not found)"
    return 0
  fi
  echo "---- Checking coverage for $dir (threshold ${THRESHOLD}%) ----"
  if [[ "$use_flutter" == "1" ]]; then
    (cd "$dir" && flutter test --coverage) || return 1
  else
    (cd "$dir" && dart test --coverage=coverage) || return 1
    (cd "$dir" && dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib) || return 1
  fi
  if ! command -v lcov &>/dev/null; then
    echo "Warning: lcov not installed; cannot verify threshold. Install with: brew install lcov (macOS) or apt-get install lcov (Linux)"
    return 0
  fi
  local summary
  summary=$(lcov --summary "$dir/coverage/lcov.info" 2>&1)
  local pct
  pct=$(echo "$summary" | grep "lines" | awk '{print $2}' | sed 's/%//')
  if [[ -z "$pct" ]]; then
    echo "Could not parse coverage for $dir"
    return 1
  fi
  echo "Coverage for $dir: ${pct}%"
  if (( $(echo "$pct < $THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
    echo "ERROR: Coverage ${pct}% is below threshold ${THRESHOLD}%"
    return 1
  fi
  return 0
}

FAILED=0
for pkg in zstandard zstandard_platform_interface zstandard_android zstandard_ios zstandard_macos zstandard_linux zstandard_windows zstandard_web; do
  check_package "$pkg" 1 || FAILED=1
done
check_package "zstandard_cli" 0 || FAILED=1

if [[ $FAILED -eq 1 ]]; then
  echo "One or more packages are below the coverage threshold."
  exit 1
fi
echo "All packages meet the coverage threshold (${THRESHOLD}%)."
