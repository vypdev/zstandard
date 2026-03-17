#!/usr/bin/env bash
# Build Linux precompiled zstd libraries for zstandard_cli (x64 and optionally ARM64).
# Uses the canonical zstd source at zstandard_native/src/zstd/. Run ./scripts/update_zstd.sh if needed.
# Usage: from repo root, run: ./scripts/build_linux.sh
# Requires: CMake, gcc, git. For ARM64: aarch64-linux-gnu-gcc or native ARM host.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/zstandard_cli"
ZSTD="$ROOT/zstandard_native/src/zstd"
BIN="$CLI/lib/src/bin"
mkdir -p "$BIN"

if [[ ! -d "$ZSTD" || ! -f "$ZSTD/zstd.h" ]]; then
  echo "Error: Canonical zstd source not found at $ZSTD"
  echo "Run: ./scripts/update_zstd.sh"
  exit 1
fi
echo "Using zstd from $ZSTD"

echo "Building Linux x64..."
cd "$CLI/builders/linux_x64"
rm -rf build && mkdir build && cd build
cmake ..
cmake --build . --config Release
mv libzstandard_linux.so "$BIN/libzstandard_linux_x64.so"
cd .. && rm -rf build

echo "Building Linux ARM64 (if toolchain available)..."
cd "$CLI/builders/linux_arm"
rm -rf build && mkdir build && cd build
if cmake -DCMAKE_TOOLCHAIN_FILE=../arm64-toolchain.cmake .. 2>/dev/null; then
  cmake --build . --config Release
  mv libzstandard_linux.so "$BIN/libzstandard_linux_arm64.so"
  echo "ARM64 built."
else
  echo "Skipping ARM64 (no toolchain or native ARM)."
fi
cd .. && rm -rf build

echo "Done. Outputs in $BIN:"
ls -la "$BIN"/*.so 2>/dev/null || true
