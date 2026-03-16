#!/usr/bin/env bash
# Run Linux integration tests on the current machine.
# Usage: from repo root, ./scripts/test_linux_integration.sh
# Requires: Linux, Flutter SDK with Linux desktop support.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux integration tests require Linux. Skipped."
  exit 0
fi

EXIT_CODE=0

echo "Running Linux integration tests..."
if (cd "$ROOT/zstandard_linux/example" && flutter test integration_test/ -d linux); then
  echo "Linux integration tests passed."
else
  EXIT_CODE=1
  echo "Linux integration tests failed."
fi

exit $EXIT_CODE
