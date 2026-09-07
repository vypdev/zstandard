[![pub package](https://img.shields.io/pub/v/zstandard_web.svg)](https://pub.dev/packages/zstandard_web)

# zstandard_web

Web implementation of [`zstandard`](https://pub.dev/packages/zstandard), built
from the same pinned zstd C source as the native packages.

## Installation

Copy all four files from this package's `blob/` directory into the Flutter
application's `web/` directory:

- `zstd.js` — small main-thread request broker;
- `zstd_worker.js` — dedicated Worker entry point;
- `zstd_core.js` — generated Emscripten runtime and safe wrappers; and
- `zstd.wasm` — compiled zstd implementation.

Load only the broker before Flutter starts:

```html
<head>
  <script src="zstd.js"></script>
</head>
```

The four files must remain together at the same relative URL. The broker
starts the Worker lazily, transfers byte buffers to it, and keeps compression
and decompression away from the browser UI thread.

## Usage

Applications normally use the federated `zstandard` package. Direct use is
also available:

```dart
final codec = ZstandardWeb();
final compressed = await codec.compress(data, 3);
final decompressed = compressed == null
    ? null
    : await codec.decompressWithOptions(
        compressed,
        maxOutputSize: 64 * 1024 * 1024,
      );
```

Compression levels are 1–22. Empty input produces a valid frame.
Decompression streams unknown-size and concatenated frames, checking every
output chunk against the configured limit. It returns `null` for malformed or
truncated input, unsupported values, Worker/WASM failures, or oversized output.
The default limit is 256 MiB.

## Generation

From the repository root:

```bash
./scripts/build_web_wasm.sh
```

The script uses the pinned Emscripten SDK revision and version, compiles
`zstandard_native/src/zstd/`, strips host metadata, and synchronizes all four
outputs into the package and both examples. Set `EMSDK_DIR` to reuse an
existing SDK. Change `EMSDK_REF` or `EMSCRIPTEN_VERSION` only as an intentional
toolchain update.

The JavaScript outputs are expected to be byte-for-byte reproducible. CI also
validates the WASM module and executes the real Worker/WASM integration in
Chrome.

## Testing

```bash
flutter test
./scripts/test_web_integration.sh
```

Run the second command from the repository root with ChromeDriver installed.
It builds the release example and exercises the generated artifacts in a real
browser.

## Troubleshooting

- If `compressData` is undefined, load `zstd.js` before Flutter.
- If the Worker or WASM fails to load, deploy all four files together and
  inspect their requests in the browser network panel.
- A `null` result is an operation failure; lower the input size, verify the
  frame, or raise `maxOutputSize` only when the application can safely accept
  the larger allocation.

See the repository [Web platform guide](https://github.com/vypdev/zstandard/blob/master/docs/platforms/web.md)
for the full architecture and deployment contract.
