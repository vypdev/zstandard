#!/usr/bin/env bash
# Build the iOS plugin (CocoaPods). Normally built when building an app.
# Usage: from repo root, run: ./scripts/build_ios.sh
# Requires: macOS, Xcode, CocoaPods.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "iOS build requires macOS."
  exit 1
fi

echo "Building zstandard_ios (pod install in example)..."
cd "$ROOT/zstandard_ios/example/ios"
pod install
echo "Done. Open Runner.xcworkspace in Xcode to build the app."
