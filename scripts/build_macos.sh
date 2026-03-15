#!/usr/bin/env bash
# Build macOS precompiled zstd libraries for zstandard_cli (Intel + ARM, universal).
# Usage: from repo root, run: ./scripts/build_macos.sh
# Requires: CMake, Xcode command line tools, git.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/zstandard_cli"
BIN="$CLI/lib/src/bin"
mkdir -p "$BIN"

echo "Fetching zstd sources into zstandard_cli/src..."
cd "$CLI"
if [[ -d "src" && -f "src/zstd.h" ]]; then
  echo "Using existing zstandard_cli/src (delete it to re-fetch)."
else
  rm -rf zstd src
  git clone --depth 1 https://github.com/facebook/zstd.git
  mkdir -p src
  mv zstd/lib/* src/
  rm -rf zstd
fi

echo "Building macOS Intel x64..."
cd "$CLI/builders/macos_intel"
rm -rf build && mkdir build && cd build
cmake ..
cmake --build . --config Release
mv libzstandard_macos.dylib "$BIN/libzstandard_macos_intel.dylib"
cd .. && rm -rf build

echo "Building macOS ARM64..."
cd "$CLI/builders/macos_arm"
rm -rf build && mkdir build && cd build
cmake -DCMAKE_OSX_ARCHITECTURES=arm64 ..
cmake --build . --config Release
mv libzstandard_macos.dylib "$BIN/libzstandard_macos_arm.dylib"
cd .. && rm -rf build

echo "Creating universal binary..."
cd "$BIN"
lipo -create -output libzstandard_macos.dylib libzstandard_macos_intel.dylib libzstandard_macos_arm.dylib
rm -f libzstandard_macos_intel.dylib libzstandard_macos_arm.dylib
lipo -info libzstandard_macos.dylib
echo "Done. Output: $BIN/libzstandard_macos.dylib"
