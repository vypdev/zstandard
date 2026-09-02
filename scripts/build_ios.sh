#!/usr/bin/env bash
# Build the iOS example with either Swift Package Manager or CocoaPods.
# Usage: from repo root, run: ./scripts/build_ios.sh
# Set ZSTANDARD_APPLE_DEPENDENCY_MANAGER=cocoapods to exercise the compatibility path.
# Requires: macOS, Xcode, and Flutter 3.44+.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "iOS build requires macOS."
  exit 1
fi

MANAGER="${ZSTANDARD_APPLE_DEPENDENCY_MANAGER:-swiftpm}"
echo "Building zstandard_ios with $MANAGER..."

case "$MANAGER" in
  swiftpm)
    flutter config --enable-swift-package-manager
    ;;
  cocoapods)
    flutter config --no-enable-swift-package-manager
    ;;
  *)
    echo "Error: ZSTANDARD_APPLE_DEPENDENCY_MANAGER must be swiftpm or cocoapods." >&2
    exit 1
    ;;
esac

cd "$ROOT/zstandard_ios/example"
flutter clean
flutter pub get
if [[ "$MANAGER" == "cocoapods" ]]; then
  (cd ios && pod install)
fi
flutter build ios --simulator --no-codesign
echo "Done. Built iOS example with $MANAGER."
