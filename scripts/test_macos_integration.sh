#!/usr/bin/env bash
# Run macOS integration tests. Flutter builds the app (and framework) when needed.
# Usage: from repo root, ./scripts/test_macos_integration.sh
# Requires: macOS (Darwin), Xcode, Flutter SDK.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macOS integration tests require Darwin. Skipped."
  exit 0
fi

EXIT_CODE=0

echo "Running macOS integration tests..."
if (cd "$ROOT/zstandard_macos/example" && flutter test integration_test/ -d macos); then
  echo "macOS integration tests passed."
else
  EXIT_CODE=1
  echo "macOS integration tests failed."
fi

exit $EXIT_CODE
