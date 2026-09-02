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
#     Install: e.g. brew install chromedriver, or use browser-actions/setup-chrome
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
if [[ -n "$ZSTANDARD_SKIP_WEB" ]]; then
  echo "Web integration tests skipped (ZSTANDARD_SKIP_WEB=1)."
elif [[ -d "$ROOT/zstandard_web/example/integration_test" ]] && [[ -d "$ROOT/zstandard_web/example/test_driver" ]]; then
  if ! command -v chromedriver &>/dev/null; then
    echo "ChromeDriver not found on PATH. Web integration tests cannot run." >&2
    echo "Install with: brew install chromedriver (or see https://docs.flutter.dev/testing/integration-tests#web)" >&2
    EXIT_CODE=1
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

    chrome_driver_ready() {
      curl --silent --fail "http://127.0.0.1:${CHROMEDRIVER_PORT}/status" >/dev/null 2>&1
    }

    run_web_driver() {
      local driver_pid=""
      local driver_log=""

      cleanup_driver() {
        if [[ -n "$driver_pid" ]] && kill -0 "$driver_pid" 2>/dev/null; then
          kill "$driver_pid" 2>/dev/null || true
          wait "$driver_pid" 2>/dev/null || true
        fi
      }
      trap cleanup_driver EXIT

      # Start ChromeDriver if nothing is listening on 4444. On Linux this
      # function is executed inside Xvfb together with Flutter and Chrome.
      if ! chrome_driver_ready; then
        driver_log=$(mktemp -t chromedriver_XXXXXX.log)
        chromedriver --port="$CHROMEDRIVER_PORT" > "$driver_log" 2>&1 &
        driver_pid=$!
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          sleep 1
          chrome_driver_ready && break
        done
        if ! chrome_driver_ready; then
          echo "ChromeDriver did not bind to port $CHROMEDRIVER_PORT. Web integration tests failed." >&2
          cat "$driver_log" >&2 || true
          return 1
        fi
      else
        echo "Using existing ChromeDriver on port $CHROMEDRIVER_PORT."
      fi

      sleep 2
      echo "Running zstandard_web example integration tests (flutter drive -d web-server)..."
      local chrome_args=()
      if [[ -n "${CHROME_EXECUTABLE:-}" ]]; then
        chrome_args+=("--chrome-binary=$CHROME_EXECUTABLE")
      fi
      flutter drive \
        --driver=test_driver/integration_test.dart \
        --target=integration_test/zstandard_web_integration_test.dart \
        --driver-port="$CHROMEDRIVER_PORT" \
        "${chrome_args[@]}" \
        --web-browser-flag=--disable-dev-shm-usage \
        --web-browser-flag=--disable-gpu \
        -d web-server \
        --web-port=8080
    }

    export -f chrome_driver_ready run_web_driver
    export CHROMEDRIVER_PORT

    DRIVE_OUTPUT=$(mktemp -t flutter_drive_XXXXXX.txt)
    if [[ "$(uname -s)" == "Linux" ]] && command -v xvfb-run >/dev/null 2>&1; then
      if (cd "$ROOT/zstandard_web/example" && xvfb-run --auto-servernum --server-args='-screen 0 1920x1080x24' bash -c 'run_web_driver') > "$DRIVE_OUTPUT" 2>&1; then
        DRIVE_EXIT=0
      else
        DRIVE_EXIT=$?
      fi
    elif (cd "$ROOT/zstandard_web/example" && run_web_driver) > "$DRIVE_OUTPUT" 2>&1; then
      DRIVE_EXIT=0
    else
      DRIVE_EXIT=$?
    fi
    # Flutter drive can exit 0 even when compilation fails; detect known failure output.
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

exit $EXIT_CODE
