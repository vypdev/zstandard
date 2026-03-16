#!/usr/bin/env bash
# Build the Android plugin native library (libzstandard_android.so).
# Used to verify the NDK/CMake build; normally the library is built when
# building an app that depends on the plugin.
# Usage: from repo root, run: ./scripts/build_android.sh
# Requires: Android SDK, NDK, and (optionally) Gradle.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/zstandard_android"

if [[ ! -d "$PLUGIN/android" ]]; then
  echo "zstandard_android not found."
  exit 1
fi

echo "Building zstandard_android native library..."
cd "$PLUGIN/android"
if command -v ./gradlew >/dev/null 2>&1; then
  ./gradlew assembleRelease
  echo "Build complete. Outputs in build/intermediates."
else
  echo "No Gradle wrapper. Run from a Flutter project or install Android SDK/NDK and add gradle wrapper."
  echo "To only verify CMake: cd $PLUGIN/android && externalNativeBuild is triggered by Gradle."
  exit 1
fi
