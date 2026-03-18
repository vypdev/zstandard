#!/usr/bin/env bash
# Run Android integration tests. Expects an emulator or device already connected.
# Usage: from repo root, ./scripts/test_android_integration.sh
# Requires: ANDROID_HOME or ANDROID_SDK_ROOT, Flutter SDK.
# Skip: ZSTANDARD_SKIP_ANDROID=1 or unset ANDROID_HOME/ANDROID_SDK_ROOT.
# Start an emulator from Android Studio or: emulator -avd <your_avd> -no-window &
# Then: flutter devices  # to get device id, or let this script pick the first device.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXIT_CODE=0

if [[ -n "$ZSTANDARD_SKIP_ANDROID" ]]; then
  echo "Android integration tests skipped (ZSTANDARD_SKIP_ANDROID=1)."
  exit 0
fi

if [[ -z "$ANDROID_HOME" && -z "$ANDROID_SDK_ROOT" ]]; then
  echo "Android integration tests skipped (ANDROID_HOME/ANDROID_SDK_ROOT not set)."
  exit 0
fi

ADB="${ANDROID_HOME:-$ANDROID_SDK_ROOT}/platform-tools/adb"
if [[ ! -x "$ADB" ]]; then
  echo "Error: adb not found. Set ANDROID_HOME or ANDROID_SDK_ROOT and install platform-tools." >&2
  exit 1
fi

# Use explicit device id if set; otherwise first connected device/emulator from adb
if [[ -n "$FLUTTER_DEVICE_ID" ]]; then
  DEVICE_ID="$FLUTTER_DEVICE_ID"
else
  DEVICE_ID=$("$ADB" devices -l 2>/dev/null | grep -E "emulator-[0-9]+\s+device|^\S+\s+device" | head -1 | awk '{print $1}')
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "No Android device or emulator found. Start an emulator from Android Studio or run:" >&2
  echo "  emulator -avd <your_avd> -no-window &" >&2
  echo "Then run this script again, or set FLUTTER_DEVICE_ID=<id> (from 'flutter devices')." >&2
  echo "To skip Android in the full suite: ZSTANDARD_SKIP_ANDROID=1 ./scripts/test_all_integration.sh" >&2
  exit 1
fi

echo "Running integration tests on device: $DEVICE_ID"
if (cd "$ROOT/zstandard_android/example" && flutter test integration_test/ -d "$DEVICE_ID"); then
  echo "Android integration tests passed."
else
  EXIT_CODE=1
  echo "Android integration tests failed."
fi

exit $EXIT_CODE
