# Web Platform Guide

The **zstandard_web** package provides the web implementation of the Zstandard Flutter plugin using JavaScript and WebAssembly (zstd compiled with Emscripten). It does not use Dart FFI.

## Support

| Environment | Support |
|-------------|---------|
| Browser (Chrome, Firefox, Safari, Edge) | Yes |
| WebAssembly | Yes (zstd.wasm) |

## Installation

1. Add the main plugin to your app:

```yaml
dependencies:
  zstandard: ^1.3.29
```

2. **Copy web assets** into your Flutter web project:
   - **zstd.js** — Emscripten-generated JS that loads and wraps the WASM module.
   - **zstd.wasm** — Compiled Zstandard C library.

   These files are provided by the zstandard_web package (e.g. under `blob/` or as documented in the package README). Copy them into your app’s `web/` directory (e.g. `web/zstd.js`, `web/zstd.wasm`).

3. **Include the script** in your `web/index.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <script src="zstd.js"></script>
</head>
<body>
  ...
</body>
</html>
```

The script must load before your Flutter app so that `compressData` and `decompressData` are available when the Dart code runs.

## Architecture

- **zstd.js** loads **zstd.wasm** and exposes global functions `compressData(inputData, compressionLevel)` and `decompressData(compressedData)`.
- **Dart** uses `dart:js_interop` (and `package:web`) to call these functions and convert between `Uint8List` and JS typed arrays.
- There is no FFI and no background isolate; compression/decompression run on the main thread. For large data, consider chunking or moving work to a Web Worker if the implementation supports it.

## Usage

Use the main package API; the web implementation is used automatically when running on web:

```dart
import 'package:zstandard/zstandard.dart';

final zstandard = Zstandard();
final compressed = await zstandard.compress(data, 3);
final decompressed = await zstandard.decompress(compressed!);
```

Or use the extensions:

```dart
final compressed = await data.compress(compressionLevel: 3);
final decompressed = await compressed?.decompress();
```

## Building zstd.js and zstd.wasm

If you need to rebuild the WebAssembly artifacts:

1. Install and activate the [Emscripten SDK](https://emscripten.org/).
2. Clone the [facebook/zstd](https://github.com/facebook/zstd) repository.
3. Run `emcc` on the zstd C sources with:
   - WASM output
   - Exported functions: `ZSTD_compress`, `ZSTD_decompress`, `ZSTD_compressBound`, `ZSTD_getFrameContentSize`, `malloc`, `free`
4. Add the wrapper functions `compressData` and `decompressData` in `zstd.js` (or a separate script) that allocate buffers, call the C functions, and return the result or null.

Detailed commands and wrapper code are in the [zstandard_web README](https://github.com/landamessenger/zstandard/tree/master/zstandard_web).

## Small Data Behavior

For very small inputs (e.g. less than 9 bytes), the implementation may return the data unchanged for compress or decompress, as zstd has a minimum frame size. Check the package source for exact behavior.

## Testing

- **Unit tests**: From the package directory: `flutter test` (some tests may require a browser or mock the JS API).
- **Integration tests**: The example app has web integration tests (e.g. `example/integration_test/zstandard_web_integration_test.dart`) that run in the browser.

## Performance characteristics

- **Single-threaded**: Compression and decompression run on the main thread (no isolates on web). Large payloads can block the UI.
- **Throughput**: Generally slower than native; level 1–3 are faster than high levels.
- **Memory**: WASM heap usage scales with input and output; consider smaller chunks for large data.

## Known limitations

- Requires `zstd.js` and `zstd.wasm` to be deployed with your app and loaded before use.
- No isolate-based offloading; heavy work runs on the main thread. For large data, consider chunking or a Web Worker (see [Advanced usage](../guides/advanced-usage.md)).
- Behavior may differ slightly from native (e.g. small-data handling, error codes). Decompress failure may throw instead of returning null.

## Troubleshooting

- **compressData / decompressData is not defined**: Ensure `zstd.js` is included in `index.html` and loads before the Flutter app. Check the browser console for script errors.
- **WASM load failed**: Ensure `zstd.wasm` is served from the same origin or with correct CORS and that the path in `zstd.js` is correct.
- **Null from compress/decompress**: Check that input is valid and that the JS functions return a typed array or null; see [Common Issues](../troubleshooting/common-issues.md).

## See Also

- [Architecture — Web Implementation](../architecture/web-implementation.md)
- [API — Main](../api/main-api.md)
