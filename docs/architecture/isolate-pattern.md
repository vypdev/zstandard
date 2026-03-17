# Isolate Pattern for Async Compression

On native platforms (Android, iOS, macOS, Linux, Windows), the plugin can run compression and decompression in a **background isolate** so that CPU-heavy work does not block the UI thread. This document describes the pattern used in the native implementations.

## Motivation

- **ZSTD_compress** and **ZSTD_decompress** are CPU-bound and can take noticeable time for large inputs.
- Dart is single-threaded per isolate. Running zstd on the main isolate would cause frame drops and jank in a Flutter app.
- **Isolates** allow running Dart code (and FFI calls) on a separate thread. The main isolate sends input and receives the result asynchronously.

## Design

The native platform packages (e.g. zstandard_linux) implement:

1. **Synchronous FFI wrappers**  
   Top-level functions such as `compress(...)` and `decompress(...)` that call the bindings and return the result size. These run in whichever isolate calls them.

2. **A long-lived helper isolate**  
   Created once (lazily) and used for all async requests. It holds the FFI bindings and runs only zstd calls.

3. **Async entry points**  
   `compressAsync` and `decompressAsync` (or similar) that:
   - Allocate buffers in the **main** isolate (or a sending isolate),
   - Send a request to the helper isolate (e.g. via `SendPort`),
   - The helper isolate runs `ZSTD_compress` or `ZSTD_decompress` and sends back the result (e.g. written size or error),
   - The main isolate copies the result into a new `Uint8List` and completes the `Future`.

4. **Public API**  
   The platform’s `compress`/`decompress` methods that implement `ZstandardPlatform` may use the synchronous wrappers on the main isolate for small inputs, or use the async path for large inputs. The exact policy (e.g. threshold) is implementation-defined. Alternatively, all work may be offloaded to the helper isolate for simplicity.

## Communication

- **Request types**: e.g. `_CompressRequest` and `_DecompressRequest` holding: request id, pointers to src/dst buffers, sizes, compression level (for compress).
- **Response types**: e.g. `_CompressResponse` and `_DecompressResponse` holding request id and result (size or error code).
- **Ports**: The main isolate has a `ReceivePort` that listens for:
  - The helper’s `SendPort` (once, at startup),
  - Response objects. Each response is matched to a `Completer` by request id; the completer is completed with the result.
- **Helper isolate**: Has a `ReceivePort` that listens for request objects, runs the appropriate zstd call, and sends the corresponding response back.

## Memory and Pointers

- **Pointers** (e.g. `Pointer<Void>`) cannot be sent between isolates; only simple values and some Dart objects can. So in the typical design:
  - Buffers are allocated in the **helper** isolate (or in shared memory if the implementation uses it). The main isolate sends only the **data** (e.g. as `Uint8List`); the helper isolate allocates, compresses/decompresses, and sends the result back as bytes (or a copy).
- Alternatively, the main isolate allocates buffers and sends a **copy** of the data; the helper isolate allocates its own buffers, copies the input, runs zstd, and sends back the output bytes. The exact approach depends on the package implementation.

## Usage in the Plugin

Application code does not see isolates directly. It only calls:

- `Zstandard().compress(data, level)`  
- `Zstandard().decompress(data)`  
- or the extension methods on `Uint8List?`

The platform implementation (e.g. `ZstandardLinux`) implements these as `Future<Uint8List?>` and may use the isolate-based async path internally so that the UI stays responsive.

## Web

The web implementation does **not** use this isolate pattern. It uses the JS/WASM API on the main thread. For large data on web, consider doing the work in a Web Worker if the implementation supports it, or chunking input to avoid long main-thread blocks.

## Related Documentation

- [Overview](overview.md)
- [FFI Implementation](ffi-implementation.md)
- [Platform Interface](platform-interface.md)
