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
  fetch_emsdk() {
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      # GitHub's checkout action configures its token as Basic auth; use the
      # same format because some self-hosted network proxies reject Bearer.
      EMSDK_AUTH=$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\r\n')
      GIT_TERMINAL_PROMPT=0 git -c http.version=HTTP/1.1 \
        -c "http.extraHeader=Authorization: basic ${EMSDK_AUTH}" \
        -C "$BUILD_DIR/emsdk" fetch --depth 1 origin "$EMSDK_REF"
    else
      GIT_TERMINAL_PROMPT=0 git -c http.version=HTTP/1.1 \
        -C "$BUILD_DIR/emsdk" fetch --depth 1 origin "$EMSDK_REF"
    fi
  }
  for attempt in 1 2 3; do
    if fetch_emsdk; then
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

EMSDK_ROOT="$EMSDK_DIR"

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
  -s EXPORTED_FUNCTIONS="['_ZSTD_compress','_ZSTD_isError','_malloc','_free','_ZSTD_compressBound','_ZSTD_createDStream','_ZSTD_initDStream','_ZSTD_decompressStream','_ZSTD_freeDStream','_ZSTD_DStreamOutSize']" \
  -s EXPORTED_RUNTIME_METHODS="['HEAPU8']" \
  -s INITIAL_MEMORY=134217728 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s MAXIMUM_MEMORY=2147483648 \
  -o zstd_core_generated.js

if [[ ! -f zstd_core_generated.js || ! -f zstd_core_generated.wasm ]]; then
  echo "Error: emcc did not produce zstd_core_generated.js / zstd_core_generated.wasm"
  exit 1
fi

# wasm-ld can emit host-dependent metadata even when the Emscripten version is
# pinned. Strip that metadata with the wasm-opt shipped by the same SDK so the
# committed binary is reproducible on Linux x64 and macOS arm64 alike.
WASM_OPT="$EMSDK_ROOT/upstream/bin/wasm-opt"
if [[ ! -x "$WASM_OPT" ]]; then
  echo "Error: wasm-opt not found in the selected Emscripten SDK: $WASM_OPT" >&2
  exit 1
fi
"$WASM_OPT" \
  --strip-debug \
  --strip-producers \
  --strip-target-features \
  --remove-unused-names \
  zstd_core_generated.wasm \
  -o zstd_normalized.wasm
mv zstd_normalized.wasm zstd_core_generated.wasm

# Append the compressData/decompressData wrappers required by the web plugin (see zstandard_web/README.md).
cat >> zstd_core_generated.js << 'WRAPPER_JS'

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

    if (!(inputData instanceof Uint8Array)
        || !Number.isInteger(compressionLevel)
        || compressionLevel < 1
        || compressionLevel > 22) {
        return null;
    }

    let inputPtr = 0;
    let outputPtr = 0;
    try {
        inputPtr = Module._malloc(Math.max(inputData.length, 1));
        if (!inputPtr) return null;
        Module.HEAPU8.set(inputData, inputPtr);

        const outputBufferSize = Number(Module._ZSTD_compressBound(inputData.length));
        if (!Number.isSafeInteger(outputBufferSize) || outputBufferSize <= 0) {
            return null;
        }
        outputPtr = Module._malloc(outputBufferSize);
        if (!outputPtr) return null;

        const compressedSize = Number(Module._ZSTD_compress(
            outputPtr,
            outputBufferSize,
            inputPtr,
            inputData.length,
            compressionLevel
        ));
        if (Module._ZSTD_isError(compressedSize) !== 0 || compressedSize <= 0) {
            console.error('Compression error, error code: ', compressedSize);
            return null;
        }
        return new Uint8Array(
            Module.HEAPU8.buffer,
            outputPtr,
            compressedSize
        ).slice();
    } finally {
        if (inputPtr) Module._free(inputPtr);
        if (outputPtr) Module._free(outputPtr);
    }
}

async function decompressData(compressedData, maxOutputSize = 256 * 1024 * 1024) {
    await moduleReady;

    if (!(compressedData instanceof Uint8Array)
        || !Number.isSafeInteger(maxOutputSize)
        || maxOutputSize < 0
        || compressedData.length === 0) {
        return null;
    }

    // ZSTD_inBuffer and ZSTD_outBuffer contain three wasm32 size_t/pointer
    // fields each. Keep their allocation and field access local to the Worker.
    const bufferStructSize = 3 * Uint32Array.BYTES_PER_ELEMENT;
    let compressedPtr = 0;
    let inputBufferPtr = 0;
    let outputBufferPtr = 0;
    let outputChunkPtr = 0;
    let stream = 0;
    try {
        compressedPtr = Module._malloc(compressedData.length);
        inputBufferPtr = Module._malloc(bufferStructSize);
        outputBufferPtr = Module._malloc(bufferStructSize);
        stream = Module._ZSTD_createDStream();
        if (!compressedPtr || !inputBufferPtr || !outputBufferPtr || !stream) {
            return null;
        }
        Module.HEAPU8.set(compressedData, compressedPtr);

        const initialization = Number(Module._ZSTD_initDStream(stream));
        if (Module._ZSTD_isError(initialization) !== 0) return null;

        const recommendedChunkSize = Number(Module._ZSTD_DStreamOutSize());
        if (!Number.isSafeInteger(recommendedChunkSize)
            || recommendedChunkSize <= 0) {
            return null;
        }
        const outputChunkSize = Math.max(
            1,
            Math.min(recommendedChunkSize, Math.max(maxOutputSize, 1)),
        );
        outputChunkPtr = Module._malloc(outputChunkSize);
        if (!outputChunkPtr) return null;

        const writeField = (structPtr, field, value) => {
            Module.HEAPU32[(structPtr >>> 2) + field] = value;
        };
        const readField = (structPtr, field) =>
            Module.HEAPU32[(structPtr >>> 2) + field];

        writeField(inputBufferPtr, 0, compressedPtr);
        writeField(inputBufferPtr, 1, compressedData.length);
        writeField(inputBufferPtr, 2, 0);

        const chunks = [];
        let totalLength = 0;
        let previousInputPosition = -1;
        let previousOutputLength = -1;
        while (true) {
            writeField(outputBufferPtr, 0, outputChunkPtr);
            writeField(outputBufferPtr, 1, outputChunkSize);
            writeField(outputBufferPtr, 2, 0);

            const remaining = Number(Module._ZSTD_decompressStream(
                stream,
                outputBufferPtr,
                inputBufferPtr,
            ));
            if (Module._ZSTD_isError(remaining) !== 0) return null;

            const inputPosition = readField(inputBufferPtr, 2);
            const produced = readField(outputBufferPtr, 2);
            if (inputPosition > compressedData.length
                || produced > outputChunkSize
                || totalLength + produced > maxOutputSize) {
                return null;
            }
            if (produced > 0) {
                chunks.push(new Uint8Array(
                    Module.HEAPU8.buffer,
                    outputChunkPtr,
                    produced,
                ).slice());
                totalLength += produced;
            }

            const allInputConsumed = inputPosition === compressedData.length;
            if (remaining === 0 && allInputConsumed) {
                const result = new Uint8Array(totalLength);
                let offset = 0;
                for (const chunk of chunks) {
                    result.set(chunk, offset);
                    offset += chunk.length;
                }
                return result;
            }

            const madeProgress = inputPosition !== previousInputPosition
                || totalLength !== previousOutputLength;
            if (!madeProgress || (allInputConsumed && produced === 0)) {
                return null;
            }
            previousInputPosition = inputPosition;
            previousOutputLength = totalLength;
        }
    } finally {
        if (stream) Module._ZSTD_freeDStream(stream);
        if (compressedPtr) Module._free(compressedPtr);
        if (inputBufferPtr) Module._free(inputBufferPtr);
        if (outputBufferPtr) Module._free(outputBufferPtr);
        if (outputChunkPtr) Module._free(outputChunkPtr);
    }
}
WRAPPER_JS

# Keep CPU-heavy zstd calls away from the browser UI thread. The public
# zstd.js file is only a small request broker; the worker loads the generated
# core and transfers byte buffers without an additional structured-clone copy.
cat > zstd_worker_generated.js << 'WORKER_JS'
'use strict';

importScripts('zstd_core.js');

self.onmessage = async (event) => {
    const { id, operation, inputBuffer, option } = event.data;
    try {
        const input = new Uint8Array(inputBuffer);
        const result = operation === 'compress'
            ? await compressData(input, option)
            : await decompressData(input, option);
        if (result === null) {
            self.postMessage({ id, result: null });
        } else {
            self.postMessage({ id, result }, [result.buffer]);
        }
    } catch (_) {
        self.postMessage({ id, result: null });
    }
};
WORKER_JS

cat > zstd_client_generated.js << 'CLIENT_JS'
'use strict';

(() => {
    const scriptUrl = document.currentScript?.src
        ?? new URL('zstd.js', document.baseURI).href;
    const workerUrl = new URL('zstd_worker.js', scriptUrl).href;
    let worker = null;
    let nextRequestId = 1;
    const pending = new Map();

    function failPendingRequests() {
        for (const resolve of pending.values()) resolve(null);
        pending.clear();
        worker?.terminate();
        worker = null;
    }

    function getWorker() {
        if (worker !== null) return worker;
        worker = new Worker(workerUrl);
        worker.onmessage = (event) => {
            const resolve = pending.get(event.data.id);
            if (resolve === undefined) return;
            pending.delete(event.data.id);
            resolve(event.data.result);
        };
        worker.onerror = failPendingRequests;
        worker.onmessageerror = failPendingRequests;
        return worker;
    }

    function run(operation, inputData, option) {
        return new Promise((resolve) => {
            const id = nextRequestId++;
            try {
                const inputCopy = inputData.slice();
                pending.set(id, resolve);
                getWorker().postMessage(
                    { id, operation, inputBuffer: inputCopy.buffer, option },
                    [inputCopy.buffer],
                );
            } catch (_) {
                pending.delete(id);
                resolve(null);
            }
        });
    }

    globalThis.compressData = (inputData, compressionLevel) =>
        run('compress', inputData, compressionLevel);
    globalThis.decompressData = (compressedData, maxOutputSize) =>
        run('decompress', compressedData, maxOutputSize);
})();
CLIENT_JS

mkdir -p "$OUT_BLOB" "$OUT_EXAMPLE_WEB" "$OUT_ZSTANDARD_EXAMPLE_WEB"

# Replace the wasm filename in the generated JS to match what we'll copy
sed -i.bak 's/zstd_core_generated\.wasm/zstd.wasm/g' zstd_core_generated.js
rm -f zstd_core_generated.js.bak

for destination in "$OUT_BLOB" "$OUT_EXAMPLE_WEB" "$OUT_ZSTANDARD_EXAMPLE_WEB"; do
  cp zstd_core_generated.wasm "$destination/zstd.wasm"
  cp zstd_core_generated.js "$destination/zstd_core.js"
  cp zstd_worker_generated.js "$destination/zstd_worker.js"
  cp zstd_client_generated.js "$destination/zstd.js"
done
rm -f \
  "$ZSTD_ROOT/zstd_core_generated.js" \
  "$ZSTD_ROOT/zstd_core_generated.wasm" \
  "$ZSTD_ROOT/zstd_worker_generated.js" \
  "$ZSTD_ROOT/zstd_client_generated.js"

echo "Done. zstd.js and zstd.wasm have been written to:"
echo "  - $OUT_BLOB/"
echo "  - $OUT_EXAMPLE_WEB/"
echo "  - $OUT_ZSTANDARD_EXAMPLE_WEB/"
echo "Built from zstandard_native/src/zstd/ (same source used by Android, iOS, macOS, Windows, Linux, and CLI)."
