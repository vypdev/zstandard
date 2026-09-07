# Web Platform Guide

The federated web implementation runs the canonical zstd C source as
WebAssembly in a dedicated browser Worker.

## Installation

Add the main package and copy all four generated assets from
`zstandard_web/blob/` to the application's `web/` directory:

```yaml
dependencies:
  zstandard: ^1.5.0
```

```text
web/zstd.js
web/zstd_worker.js
web/zstd_core.js
web/zstd.wasm
```

Load the request broker before Flutter:

```html
<head>
  <script src="zstd.js"></script>
</head>
```

The files must share a directory because the broker locates
`zstd_worker.js`, and the Worker in turn loads `zstd_core.js` and `zstd.wasm`
with relative URLs.

## Usage and failure contract

```dart
final compressed = await data.compress(compressionLevel: 3);
final decompressed = await compressed.decompress(
  maxOutputSize: 16 * 1024 * 1024,
);
```

Empty input compresses to a valid frame; short values are never returned
unchanged. Unknown-size and concatenated frames are supported. Invalid,
truncated, oversized, or otherwise failed operations return `null`,
consistently with native platforms.

## Architecture and performance

`zstd.js` transfers a copy of each input buffer to a lazily created Web Worker,
so zstd CPU work does not block browser rendering. The Worker owns the
Emscripten module. Decompression uses zstd's streaming API and rejects output
as soon as it would exceed `maxOutputSize`. The default output budget is
256 MiB; choose a smaller protocol-specific value when possible.

The WASM heap can grow to accommodate valid operations, so input and output
still determine peak memory. Limit concurrency for large payloads.

## Generation and testing

```bash
./scripts/build_web_wasm.sh
./scripts/test_web_integration.sh
```

The build is pinned and synchronizes every committed copy. Integration tests
build the example in release mode and exercise the real Worker/WASM boundary
through ChromeDriver, including event-loop yielding and output limits.

## Troubleshooting

- Undefined `compressData`: ensure `zstd.js` loads before Flutter.
- Worker/WASM network failure: deploy all four assets together with compatible
  same-origin/CORS and Content-Security-Policy rules.
- `null` decompression: validate the frame and ensure the configured output
  budget is sufficient and safe for the application.

See [Web architecture](../architecture/web-implementation.md).
