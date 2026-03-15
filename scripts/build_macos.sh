#!/usr/bin/env bash
# Build macOS precompiled zstd libraries for zstandard_cli (Intel + ARM, universal).
# Uses the canonical zstd source at repo root zstd/ (run ./scripts/sync_zstd_ios_macos.sh first or copy upstream lib/ into zstd/).
# Usage: from repo root, run: ./scripts/build_macos.sh
# Requires: CMake, Xcode command line tools.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/zstandard_cli"
ZSTD_SRC="$ROOT/zstd"
BIN="$CLI/lib/src/bin"
mkdir -p "$BIN"

if [[ ! -d "$ZSTD_SRC" || ! -f "$ZSTD_SRC/zstd.h" ]]; then
  echo "Error: Canonical zstd source not found at $ZSTD_SRC"
  echo "Run: ./scripts/update_zstd.sh   # fetches from github.com/facebook/zstd"
  exit 1
fi
echo "Using zstd from $ZSTD_SRC"

echo "Building macOS Intel x64..."
cd "$CLI/builders/macos_intel"
rm -rf build && mkdir build && cd build
cmake -DCMAKE_OSX_ARCHITECTURES=x86_64 -DZSTD_SRC_DIR="$ZSTD_SRC" ..
cmake --build . --config Release
mv libzstandard_macos.dylib "$BIN/libzstandard_macos_intel.dylib"
cd .. && rm -rf build

echo "Building macOS ARM64..."
cd "$CLI/builders/macos_arm"
rm -rf build && mkdir build && cd build
cmake -DCMAKE_OSX_ARCHITECTURES=arm64 -DZSTD_SRC_DIR="$ZSTD_SRC" ..
cmake --build . --config Release
mv libzstandard_macos.dylib "$BIN/libzstandard_macos_arm.dylib"
cd .. && rm -rf build

echo "Creating universal binary or single-arch dylib..."
cd "$BIN"
ARCH_INTEL=$(lipo -info libzstandard_macos_intel.dylib 2>/dev/null | sed -n 's/.*: \([^ ]*\) .*/\1/p' | head -1)
ARCH_ARM=$(lipo -info libzstandard_macos_arm.dylib 2>/dev/null | sed -n 's/.*: \([^ ]*\) .*/\1/p' | head -1)
if [[ -n "$ARCH_INTEL" && -n "$ARCH_ARM" && "$ARCH_INTEL" != "$ARCH_ARM" ]]; then
  lipo -create -output libzstandard_macos.dylib libzstandard_macos_intel.dylib libzstandard_macos_arm.dylib
  rm -f libzstandard_macos_intel.dylib libzstandard_macos_arm.dylib
elif [[ -f libzstandard_macos_arm.dylib ]]; then
  echo "Single architecture (arm64); using it as output."
  mv libzstandard_macos_arm.dylib libzstandard_macos.dylib
  rm -f libzstandard_macos_intel.dylib
elif [[ -f libzstandard_macos_intel.dylib ]]; then
  echo "Single architecture (x86_64); using it as output."
  mv libzstandard_macos_intel.dylib libzstandard_macos.dylib
  rm -f libzstandard_macos_arm.dylib
else
  echo "No dylib produced."; exit 1
fi
lipo -info libzstandard_macos.dylib
echo "Done. Output: $BIN/libzstandard_macos.dylib"
