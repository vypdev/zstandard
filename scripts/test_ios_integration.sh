#!/usr/bin/env bash
# Run iOS integration tests. Boots simulator if needed, runs tests.
# Usage: from repo root, ./scripts/test_ios_integration.sh
# Requires: Xcode, Flutter SDK (macOS only).

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXIT_CODE=0
SCRIPT_DIR="$ROOT/scripts"

# Start simulator if not already booted
if ! "$SCRIPT_DIR/manage_ios_simulator.sh" status 2>/dev/null; then
  echo "Booting iOS simulator..."
  "$SCRIPT_DIR/manage_ios_simulator.sh" start
fi

# Flutter accepts device id from flutter devices (e.g. UUID or "iPhone 16")
DEVICE_ID=$("$SCRIPT_DIR/manage_ios_simulator.sh" device-id)
echo "Running integration tests on device: $DEVICE_ID"

if (cd "$ROOT/zstandard_ios/example" && flutter test integration_test/ -d "$DEVICE_ID"); then
  echo "iOS integration tests passed."
else
  EXIT_CODE=1
  echo "iOS integration tests failed."
fi

exit $EXIT_CODE
