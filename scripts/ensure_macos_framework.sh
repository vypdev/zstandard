#!/usr/bin/env bash
# Ensure macOS native framework is built so tests can load it.
# Runs flutter build macos from the plugin example if framework is missing.
# Usage: from repo root, ./scripts/ensure_macos_framework.sh

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXAMPLE="$ROOT/zstandard_macos/example"
PLUGIN="$ROOT/zstandard_macos"
FRAMEWORK_NAME="zstandard_macos.framework"

# Check common locations for the built framework
framework_found() {
  [[ -d "$PLUGIN/macos/$FRAMEWORK_NAME" ]] || \
  [[ -d "$EXAMPLE/build/macos/Build/Products/Debug/$FRAMEWORK_NAME" ]] || \
  [[ -d "$EXAMPLE/.dart_tool/flutter_build/"*"/macos/$FRAMEWORK_NAME" ]] 2>/dev/null || \
  [[ -d "$EXAMPLE/macos/Flutter/ephemeral/.symlinks/plugins/zstandard_macos/macos/$FRAMEWORK_NAME" ]] 2>/dev/null
}

if framework_found; then
  echo "macOS framework already present."
  exit 0
fi

echo "Building macOS framework (flutter build macos --debug)..."
cd "$EXAMPLE"
flutter pub get
flutter build macos --debug
cd "$ROOT"

if framework_found; then
  echo "macOS framework built successfully."
else
  echo "Warning: Framework may be in a different path; integration tests will load it from the app bundle." >&2
fi
