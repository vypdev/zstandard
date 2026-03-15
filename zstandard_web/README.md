[![pub package](https://img.shields.io/pub/v/zstandard_web.svg)](https://pub.dev/packages/zstandard_web)

# zstandard_web

The web implementation of [`zstandard`](https://pub.dev/packages/zstandard).

## Installation

Copy [`zstd.js`](https://github.com/landamessenger/zstandard/raw/refs/heads/master/zstandard_web/blob/zstd.js) and [`zstd.wasm`](https://github.com/landamessenger/zstandard/raw/refs/heads/master/zstandard_web/blob/zstd.wasm) on the `web/` folder.

Include the library inside the `<head>`:

```html
<!DOCTYPE html>
<html>
<head>
  <script src="zstd.js"></script>
</head>
</html>
```

## Usage

```dart
void act() async {
  final zstandard = ZstandardWeb();

  Uint8List original = Uint8List.fromList([...]);

  Uint8List? compressed = await zstandard.compress(original);
  
  Uint8List? decompressed = await zstandard.decompress(compressed ?? Uint8List(0));
}
```

<p align="center"><img width="90%" vspace="10" src="https://github.com/landamessenger/zstandard/raw/master/zstandard_web/images/sample.png"></p>

## Generation

`zstd.js` and `zstd.wasm` generation:

```bash
git clone https://github.com/emscripten-core/emsdk.git

git clone https://github.com/facebook/zstd.git
```

```bash
cd emsdk

./emsdk install latest

./emsdk activate latest

source "$HOME/Development/emsdk/emsdk_env.sh"

echo 'source "$HOME/Development/emsdk/emsdk_env.sh"' >> $HOME/.zprofile

```

```bash
cd zstd

emcc -O3 \
    $(find lib/compress -name "*.c") \
    $(find lib/decompress -name "*.c") \
    $(find lib/common -name "*.c") \
    -s WASM=1 \
    -s EXPORT_NAME="zstdWasmModule" \
    -s EXPORTED_FUNCTIONS="['_ZSTD_compress', '_ZSTD_decompress', '_malloc', '_free', '_ZSTD_getFrameContentSize', '_ZSTD_compressBound']" \
    -o zstd.js
```

Include `compressData` and `decompressData` methods in `zstd.js`:

```js
function compressData(inputData, compressionLevel) {
    let inputPtr = Module._malloc(inputData.length);
    Module.HEAPU8.set(inputData, inputPtr);

    let outputBufferSize = Module._ZSTD_compressBound(inputData.length);
    let outputPtr = Module._malloc(outputBufferSize);

    let compressedSize = Module._ZSTD_compress(
        outputPtr,
        outputBufferSize,
        inputPtr,
        inputData.length,
        compressionLevel
    );

    if (compressedSize < 0) {
        console.error('Compression error, error code: ', compressedSize);
        return null;
    } else {
        let compressedData = new Uint8Array(Module.HEAPU8.buffer, outputPtr, compressedSize);

        Module._free(inputPtr);
        Module._free(outputPtr);

        return compressedData;
    }
}

function decompressData(compressedData) {
    let compressedPtr = Module._malloc(compressedData.length);
    Module.HEAPU8.set(compressedData, compressedPtr);

    let decompressedSize = Module._ZSTD_getFrameContentSize(compressedPtr, compressedData.length);
    if (decompressedSize === -1 || decompressedSize === -2) {
        console.error('Error in obtaining the original size of the data');
        Module._free(compressedPtr);
        return null;
    }

    let decompressedPtr = Module._malloc(decompressedSize);

    let resultSize = Module._ZSTD_decompress(
        decompressedPtr,
        decompressedSize,
        compressedPtr,
        compressedData.length
    );

    if (resultSize < 0) {
        console.error('Decompression error, error code: ', resultSize);
        Module._free(compressedPtr);
        Module._free(decompressedPtr);
        return null;
    } else {
        let decompressedData = new Uint8Array(Module.HEAPU8.buffer, decompressedPtr, resultSize);

        Module._free(compressedPtr);
        Module._free(decompressedPtr);

        return decompressedData;
    }
}
```

## API

- **ZstandardWeb()** — Creates the web platform implementation.
- **compress(Uint8List data, int compressionLevel)** — Compresses `data` (level 1–22). Returns compressed bytes or throws on failure. Inputs smaller than 9 bytes may be returned unchanged.
- **decompress(Uint8List data)** — Decompresses zstd-compressed data. Returns decompressed bytes or throws on failure.
- **getPlatformVersion()** — Returns the browser user agent string.

## Architecture

This package uses JavaScript interop and WebAssembly. It calls the global `compressData` and `decompressData` functions provided by `zstd.js`, which in turn use the compiled zstd C library in `zstd.wasm`. No Dart FFI; runs on the main thread.

## Testing

From the package directory:

```bash
flutter test
```

Unit tests run only on web (skipped on other platforms). Full integration tests are in `example/integration_test/` and require a browser (e.g. `flutter test integration_test/ -d chrome`).

## Troubleshooting

- **compressData / decompressData is not defined**: Ensure `zstd.js` is included in your `web/index.html` and loads before the Flutter app.
- **WASM load failed**: Ensure `zstd.wasm` is served from the same origin and the path is correct. Check the browser console and network tab.

See the [documentation](https://github.com/landamessenger/zstandard/tree/master/docs) for more.
