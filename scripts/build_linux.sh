#!/usr/bin/env bash
# Build Linux precompiled zstd libraries for zstandard_cli (x64 and optionally ARM64).
# Usage: from repo root, run: ./scripts/build_linux.sh
# Requires: CMake, gcc, git. For ARM64: aarch64-linux-gnu-gcc or native ARM host.

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
