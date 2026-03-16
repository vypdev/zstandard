#!/usr/bin/env bash
# Run web tests in Chrome: unit tests (flutter test -d chrome) and integration
# tests (flutter drive with ChromeDriver + web-server).
#
# Usage: from repo root, ./scripts/test_web_integration.sh
#
# Requires:
#   - Flutter SDK
#   - Chrome browser
#   - ChromeDriver on PATH (port 4444 for integration tests).
#     Install: e.g. brew install chromedriver, or
#     npx @puppeteer/browsers install chromedriver@stable
#     See: https://docs.flutter.dev/testing/integration-tests#web

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXIT_CODE=0
CHROMEDRIVER_PID=""
CHROMEDRIVER_PORT=4444

# If we start ChromeDriver, stop it on exit.
cleanup_chromedriver() {
  if [[ -n "$CHROMEDRIVER_PID" ]] && kill -0 "$CHROMEDRIVER_PID" 2>/dev/null; then
    kill "$CHROMEDRIVER_PID" 2>/dev/null || true
    wait "$CHROMEDRIVER_PID" 2>/dev/null || true
  fi
}
trap cleanup_chromedriver EXIT

# --- Unit tests (Chrome), if the package has any ---
WEB_TEST_COUNT=$(find "$ROOT/zstandard_web/test" -name "*_test.dart" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$WEB_TEST_COUNT" -gt 0 ]]; then
  echo "Running zstandard_web unit tests in Chrome..."
  if (cd "$ROOT/zstandard_web" && flutter test -d chrome --coverage 2>/dev/null || flutter test -d chrome); then
    echo "Web unit tests passed."
  else
    EXIT_CODE=1
    echo "Web unit tests failed."
  fi
else
  echo "No zstandard_web unit tests (coverage in example/integration_test); see zstandard_web/test/README.md."
fi

# --- Integration tests (flutter drive + ChromeDriver + web-server) ---
if [[ -d "$ROOT/zstandard_web/example/integration_test" ]] && [[ -d "$ROOT/zstandard_web/example/test_driver" ]]; then
  if ! command -v chromedriver &>/dev/null; then
    echo "ChromeDriver not found on PATH. Skipping web integration tests."
    echo "Install with: brew install chromedriver (or see https://docs.flutter.dev/testing/integration-tests#web)"
  else
    # On macOS, remove quarantine so Gatekeeper doesn't block chromedriver (avoids security popup)
    if [[ "$(uname -s)" = Darwin ]]; then
      CHROMEDRIVER_BIN=$(command -v chromedriver)
      while [[ -L "$CHROMEDRIVER_BIN" ]]; do
        NEXT=$(readlink "$CHROMEDRIVER_BIN")
        [[ "$NEXT" != /* ]] && NEXT="$(dirname "$CHROMEDRIVER_BIN")/$NEXT"
        CHROMEDRIVER_BIN=$NEXT
      done
      if [[ -f "$CHROMEDRIVER_BIN" ]] && xattr "$CHROMEDRIVER_BIN" 2>/dev/null | grep -q com.apple.quarantine; then
        xattr -d com.apple.quarantine "$CHROMEDRIVER_BIN" 2>/dev/null || true
      fi
    fi

    # Start ChromeDriver if nothing is listening on 4444
    if ! lsof -i:"$CHROMEDRIVER_PORT" &>/dev/null; then
      chromedriver --port="$CHROMEDRIVER_PORT" &
      CHROMEDRIVER_PID=$!
      # Wait until port is listening (up to 10s)
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        sleep 1
        lsof -i:"$CHROMEDRIVER_PORT" &>/dev/null && break
      done
      if ! lsof -i:"$CHROMEDRIVER_PORT" &>/dev/null; then
        echo "ChromeDriver did not bind to port $CHROMEDRIVER_PORT. Skipping integration tests."
        echo "Start it manually in another terminal: chromedriver --port=4444"
      fi
    else
      echo "Using existing ChromeDriver on port $CHROMEDRIVER_PORT."
    fi

    if lsof -i:"$CHROMEDRIVER_PORT" &>/dev/null; then
      # Brief wait so ChromeDriver is fully ready before flutter drive starts the server and tests
      sleep 2
      echo "Running zstandard_web example integration tests (flutter drive -d web-server)..."
      DRIVE_OUTPUT=$(mktemp -t flutter_drive_XXXXXX.txt)
      (cd "$ROOT/zstandard_web/example" && flutter drive \
        --driver=test_driver/integration_test.dart \
        --target=integration_test/zstandard_web_integration_test.dart \
        -d web-server \
        --web-port=8080) > "$DRIVE_OUTPUT" 2>&1
      DRIVE_EXIT=$?
      # Flutter drive can exit 0 even when compilation fails; detect known failure output
      if [[ $DRIVE_EXIT -ne 0 ]] || grep -qE "Failed to compile|Dart compiler exited unexpectedly|SessionNotCreatedException|Unable to start a WebDriver session" "$DRIVE_OUTPUT"; then
        EXIT_CODE=1
        echo "Web integration tests failed."
        cat "$DRIVE_OUTPUT"
      else
        echo "Web integration tests passed."
        cat "$DRIVE_OUTPUT"
      fi
      rm -f "$DRIVE_OUTPUT"
    fi
  fi
fi

exit $EXIT_CODE
