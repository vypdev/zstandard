#!/usr/bin/env bash
# Build zstd.js and zstd.wasm from zstandard_native/src/zstd/ using Emscripten (emsdk),
# then copy them to zstandard_web/blob/ and zstandard_web/example/web/, and add the compressData/decompressData
# wrappers expected by the web plugin.
#
# Usage: from repo root, run: ./scripts/build_web_wasm.sh
#
# Requires: git. Downloads emsdk into a temporary directory and removes it
# after the build. The single source for zstd C code is zstandard_native/src/zstd/
# (development only; this script runs from the repository).
#
# See zstandard_web/README.md for usage of the generated files.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSTD_ROOT="$ROOT/zstandard_native/src/zstd"
OUT_BLOB="$ROOT/zstandard_web/blob"
OUT_EXAMPLE_WEB="$ROOT/zstandard_web/example/web"
OUT_ZSTANDARD_EXAMPLE_WEB="$ROOT/zstandard/example/web"

if [[ ! -d "$ZSTD_ROOT" || ! -f "$ZSTD_ROOT/zstd.h" ]]; then
  echo "Error: Canonical zstd source not found at $ZSTD_ROOT (expected zstd.h)."
  echo "This script only runs from the repository root during development."
  echo "Run: ./scripts/update_zstd.sh   # fetches into zstandard_native/src/zstd/"
  exit 1
fi

EMSDK_REF="${EMSDK_REF:-a36df02dc438e8b02f91122a4c62eeecb6784272}"
EMSCRIPTEN_VERSION="${EMSCRIPTEN_VERSION:-3.1.69}"
EMSDK_DIR="${EMSDK_DIR:-}"

if [[ -z "$EMSDK_DIR" ]]; then
  BUILD_DIR=$(mktemp -d)
  trap 'rm -rf "$BUILD_DIR"' EXIT

  echo "Cloning emsdk at $EMSDK_REF into $BUILD_DIR ..."
  git init -q "$BUILD_DIR/emsdk"
  git -C "$BUILD_DIR/emsdk" remote add origin https://github.com/emscripten-core/emsdk.git
  # Some self-hosted networks reject anonymous GitHub fetches even for public
  # repositories. Use the ephemeral Actions token when CI provides one, while
  # keeping local development fully anonymous. Disable prompting so a runner
  # cannot hang forever waiting for credentials, and retry transient failures.
  EMSDK_FETCH_AUTH=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    # GitHub's checkout action configures its token as Basic auth; use the
    # same format because some self-hosted network proxies reject Bearer.
    EMSDK_AUTH=$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\r\n')
    EMSDK_FETCH_AUTH=(-c "http.extraHeader=Authorization: basic ${EMSDK_AUTH}")
  fi
  for attempt in 1 2 3; do
    if GIT_TERMINAL_PROMPT=0 git -c http.version=HTTP/1.1 \
      "${EMSDK_FETCH_AUTH[@]}" \
      -C "$BUILD_DIR/emsdk" fetch --depth 1 origin "$EMSDK_REF"; then
      break
    fi
    if [[ "$attempt" -eq 3 ]]; then
      echo "Error: unable to fetch emsdk commit $EMSDK_REF after $attempt attempts." >&2
      exit 1
    fi
    echo "emsdk fetch failed; retrying ($((attempt + 1))/3) ..." >&2
    sleep 5
  done
  git -C "$BUILD_DIR/emsdk" checkout --detach FETCH_HEAD
  EMSDK_DIR="$BUILD_DIR/emsdk"

  echo "Installing and activating Emscripten $EMSCRIPTEN_VERSION ..."
  cd "$EMSDK_DIR"
  ./emsdk install "$EMSCRIPTEN_VERSION"
  ./emsdk activate "$EMSCRIPTEN_VERSION"
else
  if [[ ! -f "$EMSDK_DIR/emsdk_env.sh" ]]; then
    echo "Error: EMSDK_DIR does not contain emsdk_env.sh: $EMSDK_DIR" >&2
    exit 1
  fi
  echo "Using Emscripten SDK from $EMSDK_DIR ..."
fi

# shellcheck source=/dev/null
source "$EMSDK_DIR/emsdk_env.sh"

emcc --version

echo "Building zstd with emcc from $ZSTD_ROOT ..."
cd "$ZSTD_ROOT"

# Same exports as documented in zstandard_web/README.md; only common/compress/decompress (no legacy/dictBuilder).
COMMON_SRC=$(find common -name "*.c" 2>/dev/null | sort | tr '\n' ' ')
COMPRESS_SRC=$(find compress -name "*.c" 2>/dev/null | sort | tr '\n' ' ')
DECOMPRESS_SRC=$(find decompress -name "*.c" 2>/dev/null | sort | tr '\n' ' ')

emcc -O3 \
  $COMMON_SRC $COMPRESS_SRC $DECOMPRESS_SRC \
  -I. -Icommon -Icompress -Idecompress \
  -s WASM=1 \
  -s EXPORT_NAME="zstdWasmModule" \
  -s EXPORTED_FUNCTIONS="['_ZSTD_compress','_ZSTD_decompress','_malloc','_free','_ZSTD_getFrameContentSize','_ZSTD_compressBound']" \
  -s EXPORTED_RUNTIME_METHODS="['HEAPU8']" \
  -s INITIAL_MEMORY=134217728 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s MAXIMUM_MEMORY=2147483648 \
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

mkdir -p "$OUT_BLOB" "$OUT_EXAMPLE_WEB" "$OUT_ZSTANDARD_EXAMPLE_WEB"

# Replace the wasm filename in the generated JS to match what we'll copy
sed -i.bak 's/zstd_generated\.wasm/zstd.wasm/g' zstd_generated.js
rm -f zstd_generated.js.bak

cp zstd_generated.wasm "$OUT_BLOB/zstd.wasm"
cp zstd_generated.wasm "$OUT_EXAMPLE_WEB/zstd.wasm"
cp zstd_generated.wasm "$OUT_ZSTANDARD_EXAMPLE_WEB/zstd.wasm"
cp zstd_generated.js "$OUT_BLOB/zstd.js"
cp zstd_generated.js "$OUT_EXAMPLE_WEB/zstd.js"
cp zstd_generated.js "$OUT_ZSTANDARD_EXAMPLE_WEB/zstd.js"
rm -f "$ZSTD_ROOT/zstd_generated.js" "$ZSTD_ROOT/zstd_generated.wasm"

echo "Done. zstd.js and zstd.wasm have been written to:"
echo "  - $OUT_BLOB/"
echo "  - $OUT_EXAMPLE_WEB/"
echo "  - $OUT_ZSTANDARD_EXAMPLE_WEB/"
echo "Built from zstandard_native/src/zstd/ (same source used by Android, iOS, macOS, Windows, Linux, and CLI)."
