#!/usr/bin/env bash
# Run Linux integration tests on the current machine.
# Usage: from repo root, ./scripts/test_linux_integration.sh
# Requires: Linux, Flutter SDK with Linux desktop support, CMake, GTK, and Xvfb.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux integration tests require Linux. Skipped."
  exit 0
fi

EXIT_CODE=0

echo "Running Linux integration tests..."
if (cd "$ROOT/zstandard_linux/example" && flutter build linux --debug); then
  echo "Linux example build passed."
else
  echo "Linux example build failed."
  exit 1
fi

if command -v xvfb-run >/dev/null 2>&1; then
  TEST_COMMAND=(xvfb-run --auto-servernum --server-args='-screen 0 1920x1080x24' flutter test integration_test/ -d linux)
else
  TEST_COMMAND=(flutter test integration_test/ -d linux)
fi

if (cd "$ROOT/zstandard_linux/example" && "${TEST_COMMAND[@]}" ); then
  echo "Linux integration tests passed."
else
  EXIT_CODE=1
  echo "Linux integration tests failed."
fi

exit $EXIT_CODE
