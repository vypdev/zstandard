#!/usr/bin/env bash
# Run all tests with full coverage (no skipeos). Uses integration tests and Chrome for web.
# Usage: from repo root, ./scripts/test_all_integration.sh
# Requires: Flutter SDK, Dart SDK. On macOS: Xcode (iOS/macOS), Android SDK (Android), Chrome (web).
# Optional: ZSTANDARD_SKIP_ANDROID=1 to skip Android (e.g. if emulator is slow or unavailable).

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SCRIPT_DIR="$ROOT/scripts"
FAILED=0

run() {
  if "$@"; then
    echo "OK: $*"
    return 0
  else
    echo "FAILED: $*"
    FAILED=1
    return 1
  fi
}

echo "=== Running integration tests (no skipeos) ==="

# 1. Pure Dart / VM tests
echo ""
echo "1/8 Testing platform interface..."
run bash -c "cd $ROOT/zstandard_platform_interface && flutter test"

echo ""
echo "2/8 Testing main package..."
run bash -c "cd $ROOT/zstandard && flutter test"

echo ""
echo "3/8 Testing CLI..."
run bash -c "cd $ROOT/zstandard_cli && dart test"

# 2. Android (emulator; skip with ZSTANDARD_SKIP_ANDROID=1 or increase ZSTANDARD_AVD_BOOT_TIMEOUT)
echo ""
echo "4/8 Testing Android (integration tests on emulator)..."
if [[ -n "$ZSTANDARD_SKIP_ANDROID" ]]; then
  echo "Skipped (ZSTANDARD_SKIP_ANDROID=1)."
else
  run "$SCRIPT_DIR/test_android_integration.sh" || true
fi

# 3. iOS (simulator)
echo ""
echo "5/8 Testing iOS (integration tests on simulator)..."
if [[ "$(uname)" == "Darwin" ]]; then
  run "$SCRIPT_DIR/test_ios_integration.sh" || true
else
  echo "Skipped (iOS requires macOS)."
fi

# 4. macOS (framework + integration tests)
echo ""
echo "6/8 Testing macOS (build framework + integration tests)..."
run "$SCRIPT_DIR/test_macos_integration.sh" || true

# 5. Web (Chrome)
echo ""
echo "7/8 Testing Web (Chrome)..."
run "$SCRIPT_DIR/test_web_integration.sh" || true

# 6. Linux (when on Linux)
echo ""
echo "8/8 Testing Linux / Windows..."
if [[ "$(uname -s)" == "Linux" ]]; then
  run "$SCRIPT_DIR/test_linux_integration.sh" || true
elif [[ "$(uname -s)" == *"MINGW"* ]] || [[ "$(uname -s)" == *"MSYS"* ]]; then
  run bash -c "cd \"$ROOT\" && cmd //c 'scripts\\\\test_windows_integration.bat'" || true
else
  echo "Linux/Windows: run on native OS: ./scripts/test_linux_integration.sh or scripts\\test_windows_integration.bat"
fi

echo ""
if [[ $FAILED -eq 1 ]]; then
  echo "=== One or more test suites failed. ==="
  exit 1
fi
echo "=== All tests completed successfully. ==="
