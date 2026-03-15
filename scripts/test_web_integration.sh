#!/usr/bin/env bash
# Run web tests in Chrome (headless). Unit tests and integration tests.
# Usage: from repo root, ./scripts/test_web_integration.sh
# Requires: Flutter SDK, Chrome.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXIT_CODE=0

echo "Running zstandard_web unit tests in Chrome..."
if (cd "$ROOT/zstandard_web" && flutter test -d chrome --coverage 2>/dev/null || flutter test -d chrome); then
  echo "Web unit tests passed."
else
  EXIT_CODE=1
  echo "Web unit tests failed."
fi

# Optionally run example integration tests in Chrome
if [[ -d "$ROOT/zstandard_web/example/integration_test" ]]; then
  echo "Running zstandard_web example integration tests in Chrome..."
  if (cd "$ROOT/zstandard_web/example" && flutter test integration_test/ -d chrome); then
    echo "Web integration tests passed."
  else
    EXIT_CODE=1
    echo "Web integration tests failed."
  fi
fi

exit $EXIT_CODE
