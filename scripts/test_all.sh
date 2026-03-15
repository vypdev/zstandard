#!/usr/bin/env bash
# Run all unit tests across zstandard packages.
# Usage: from repo root, run: ./scripts/test_all.sh
# Requires: Flutter SDK (for Flutter packages), Dart SDK (for CLI).

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FAILED=0

run_test() {
  local dir="$1"
  local runner="$2"
  if [[ ! -d "$dir" ]]; then
    echo "Skip $dir (not found)"
    return 0
  fi
  echo "---- Testing $dir ----"
  if (cd "$dir" && $runner); then
    echo "OK $dir"
    return 0
  else
    echo "FAILED $dir"
    FAILED=1
    return 1
  fi
}

# Flutter packages
for pkg in zstandard zstandard_platform_interface zstandard_android zstandard_ios zstandard_macos zstandard_linux zstandard_windows zstandard_web; do
  run_test "$pkg" "flutter test" || true
done

# CLI is pure Dart
run_test "zstandard_cli" "dart test" || true

if [[ $FAILED -eq 1 ]]; then
  echo "One or more packages had test failures."
  exit 1
fi
echo "All tests passed."
