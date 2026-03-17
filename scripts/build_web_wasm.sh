#!/usr/bin/env bash
# Build zstd.js and zstd.wasm from the repo's zstd/ using Emscripten (emsdk),
# then copy them to zstandard_web/blob/ and zstandard_web/example/web/, and add the compressData/decompressData
# wrappers expected by the web plugin.
#
# Usage: from repo root, run: ./scripts/build_web_wasm.sh
#
# Requires: git. Downloads emsdk into a temporary directory and removes it
# after the build. The single source for zstd C code is zstd/ at repo root
# (same as Android, iOS, macOS, Windows, Linux, and CLI).
#
# See zstandard_web/README.md for usage of the generated files.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSTD_ROOT="$ROOT/zstd"
OUT_BLOB="$ROOT/zstandard_web/blob"
OUT_EXAMPLE_WEB="$ROOT/zstandard_web/example/web"

if [[ ! -d "$ZSTD_ROOT" || ! -f "$ZSTD_ROOT/zstd.h" ]]; then
  echo "Error: Canonical zstd source not found at $ZSTD_ROOT (expected zstd.h)."
  echo "Run: ./scripts/update_zstd.sh"
  exit 1
fi

BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "Cloning emsdk into $BUILD_DIR ..."
git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$BUILD_DIR/emsdk"

echo "Installing and activating Emscripten (latest) ..."
cd "$BUILD_DIR/emsdk"
./emsdk install latest
./emsdk activate latest
# shellcheck source=/dev/null
source ./emsdk_env.sh

echo "Building zstd with emcc from $ZSTD_ROOT ..."
cd "$ZSTD_ROOT"

# Same exports as documented in zstandard_web/README.md; only common/compress/decompress (no legacy/dictBuilder).
COMMON_SRC=$(find common -name "*.c" 2>/dev/null | tr '\n' ' ')
COMPRESS_SRC=$(find compress -name "*.c" 2>/dev/null | tr '\n' ' ')
DECOMPRESS_SRC=$(find decompress -name "*.c" 2>/dev/null | tr '\n' ' ')

emcc -O3 \
  $COMMON_SRC $COMPRESS_SRC $DECOMPRESS_SRC \
  -I. -Icommon -Icompress -Idecompress \
  -s WASM=1 \
  -s EXPORT_NAME="zstdWasmModule" \
  -s EXPORTED_FUNCTIONS="['_ZSTD_compress','_ZSTD_decompress','_malloc','_free','_ZSTD_getFrameContentSize','_ZSTD_compressBound']" \
  -s EXPORTED_RUNTIME_METHODS="['HEAPU8']" \
  -o zstd_generated.js

if [[ ! -f zstd_generated.js || ! -f zstd_generated.wasm ]]; then
  echo "Error: emcc did not produce zstd_generated.js / zstd_generated.wasm"
  exit 1
fi

# Append the compressData/decompressData wrappers required by the web plugin (see zstandard_web/README.md).
cat >> zstd_generated.js << 'WRAPPER_JS'

// Promise that resolves when the module is ready
let moduleReady = new Promise((resolve) => {
    if (typeof Module !== 'undefined' && Module.calledRun) {
        // Module already initialized
        resolve();
    } else {
        // Wait for module initialization
        const originalOnRuntimeInitialized = Module.onRuntimeInitialized || function() {};
        Module.onRuntimeInitialized = function() {
            originalOnRuntimeInitialized();
            resolve();
        };
    }
});

async function compressData(inputData, compressionLevel) {
    await moduleReady;
    
    let inputPtr = Module._malloc(inputData.length);
    Module.HEAPU8.set(inputData, inputPtr);

    let outputBufferSize = Number(Module._ZSTD_compressBound(inputData.length));
    let outputPtr = Module._malloc(outputBufferSize);

    let compressedSize = Number(Module._ZSTD_compress(
        outputPtr,
        outputBufferSize,
        inputPtr,
        inputData.length,
        compressionLevel
    ));

    if (compressedSize < 0) {
        console.error('Compression error, error code: ', compressedSize);
        Module._free(inputPtr);
        Module._free(outputPtr);
        return null;
    } else {
        let compressedData = new Uint8Array(Module.HEAPU8.buffer, outputPtr, compressedSize);
        let out = compressedData.slice(0);
        Module._free(inputPtr);
        Module._free(outputPtr);
        return out;
    }
}

async function decompressData(compressedData) {
    await moduleReady;
    
    let compressedPtr = Module._malloc(compressedData.length);
    Module.HEAPU8.set(compressedData, compressedPtr);

    let decompressedSize = Number(Module._ZSTD_getFrameContentSize(compressedPtr, compressedData.length));
    if (decompressedSize === -1 || decompressedSize === -2) {
        console.error('Error in obtaining the original size of the data');
        Module._free(compressedPtr);
        return null;
    }

    let decompressedPtr = Module._malloc(decompressedSize);

    let resultSize = Number(Module._ZSTD_decompress(
        decompressedPtr,
        decompressedSize,
        compressedPtr,
        compressedData.length
    ));

    if (resultSize < 0) {
        console.error('Decompression error, error code: ', resultSize);
        Module._free(compressedPtr);
        Module._free(decompressedPtr);
        return null;
    } else {
        let decompressedData = new Uint8Array(Module.HEAPU8.buffer, decompressedPtr, resultSize);
        let out = decompressedData.slice(0);
        Module._free(compressedPtr);
        Module._free(decompressedPtr);
        return out;
    }
}
WRAPPER_JS

mkdir -p "$OUT_BLOB" "$OUT_EXAMPLE_WEB"

# Replace the wasm filename in the generated JS to match what we'll copy
sed -i.bak 's/zstd_generated\.wasm/zstd.wasm/g' zstd_generated.js
rm -f zstd_generated.js.bak

cp zstd_generated.wasm "$OUT_BLOB/zstd.wasm"
cp zstd_generated.wasm "$OUT_EXAMPLE_WEB/zstd.wasm"
cp zstd_generated.js "$OUT_BLOB/zstd.js"
cp zstd_generated.js "$OUT_EXAMPLE_WEB/zstd.js"
rm -f "$ZSTD_ROOT/zstd_generated.js" "$ZSTD_ROOT/zstd_generated.wasm"

echo "Done. zstd.js and zstd.wasm have been written to:"
echo "  - $OUT_BLOB/"
echo "  - $OUT_EXAMPLE_WEB/"
echo "Built from the same zstd/ source used by Android, iOS, macOS, Windows, Linux, and CLI."
