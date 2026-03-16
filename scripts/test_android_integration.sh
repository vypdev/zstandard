#!/usr/bin/env bash
# Run Android integration tests. Starts emulator if needed, runs tests.
# Usage: from repo root, ./scripts/test_android_integration.sh
# Requires: ANDROID_HOME or ANDROID_SDK_ROOT, Flutter SDK.
# Skip: ZSTANDARD_SKIP_ANDROID=1 or unset ANDROID_HOME/ANDROID_SDK_ROOT.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXIT_CODE=0
SCRIPT_DIR="$ROOT/scripts"

if [[ -n "$ZSTANDARD_SKIP_ANDROID" ]]; then
  echo "Android integration tests skipped (ZSTANDARD_SKIP_ANDROID=1)."
  exit 0
fi

if [[ -z "$ANDROID_HOME" && -z "$ANDROID_SDK_ROOT" ]]; then
  echo "Android integration tests skipped (ANDROID_HOME/ANDROID_SDK_ROOT not set)."
  exit 0
fi

# Start emulator if not already running
if ! "$SCRIPT_DIR/manage_android_emulator.sh" status 2>/dev/null; then
  echo "Starting Android emulator (this can take 2–4 minutes on first boot)..."
  if ! DEVICE_ID=$("$SCRIPT_DIR/manage_android_emulator.sh" start); then
    echo "Android emulator failed to start. To skip Android: ZSTANDARD_SKIP_ANDROID=1 ./scripts/test_all_integration.sh"
    echo "To increase boot timeout: ZSTANDARD_AVD_BOOT_TIMEOUT=300 ./scripts/test_android_integration.sh"
    exit 1
  fi
else
  DEVICE_ID=$("$SCRIPT_DIR/manage_android_emulator.sh" device-id)
fi

echo "Running integration tests on device: $DEVICE_ID"
if (cd "$ROOT/zstandard_android/example" && flutter test integration_test/ -d "$DEVICE_ID"); then
  echo "Android integration tests passed."
else
  EXIT_CODE=1
  echo "Android integration tests failed."
fi

exit $EXIT_CODE
