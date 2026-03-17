# FFI Implementation

Native platforms (Android, iOS, macOS, Linux, Windows) use Dart’s **FFI (Foreign Function Interface)** to call the Zstandard C library directly. This document describes the shared pattern used across these implementations.

## Overview

Each native platform package:

1. Ships or builds the official [facebook/zstd](https://github.com/facebook/zstd) C library for that platform.
2. Generates Dart FFI bindings (e.g. with `ffigen`) for the zstd functions used by the plugin.
3. Opens the native library at runtime and calls `ZSTD_compress`, `ZSTD_decompress`, `ZSTD_compressBound`, and `ZSTD_getFrameContentSize` from Dart.
4. Manages memory (allocate output buffers, copy bytes, free) using `package:ffi` (e.g. `malloc.allocate` / `malloc.free`).

## Shared C API Usage

The plugin uses a minimal subset of the zstd C API:

| C function | Purpose |
|------------|---------|
| `ZSTD_compressBound(srcSize)` | Upper bound for compressed size; used to allocate the destination buffer. |
| `ZSTD_compress(dst, dstCapacity, src, srcSize, compressionLevel)` | Compresses `src` into `dst`; returns compressed size or an error code. |
| `ZSTD_getFrameContentSize(src, srcSize)` | Gets original size from a zstd frame (or -1 / -2 if unknown/error). |
| `ZSTD_decompress(dst, dstCapacity, src, srcSize)` | Decompresses `src` into `dst`; returns decompressed size or an error code. |

## Binding Generation

Bindings are typically generated with **ffigen** from the zstd headers. The generated Dart file (e.g. `zstandard_linux_bindings_generated.dart`) exposes a class that wraps the `DynamicLibrary` and provides typed Dart methods for the C functions above.

Example pattern:

```dart
final DynamicLibrary _dylib = DynamicLibrary.open('libzstandard_linux_plugin.so');
final ZstandardLinuxBindings _bindings = ZstandardLinuxBindings(_dylib);
```

Library names and loading differ per platform (e.g. `.so` on Linux/Android, `.dylib` on macOS/iOS, `.dll` on Windows). Each platform’s `lib/` code opens the appropriate library and instantiates the bindings once.

## Memory Management

Compression and decompression follow the same pattern across native implementations:

1. **Allocate** input buffer with `malloc.allocate<Uint8>(size)` and copy `Uint8List` into it.
2. **Allocate** output buffer:
   - Compression: size = `ZSTD_compressBound(srcSize)`
   - Decompression: size = from `ZSTD_getFrameContentSize` or a fallback (e.g. `compressedSize * 20`) when size is unknown.
3. **Call** `ZSTD_compress` or `ZSTD_decompress`.
4. **Copy** result into a new `Uint8List` (only the written length).
5. **Free** both buffers in a `finally` block so memory is always released.

All platforms use this pattern to avoid leaks and to stay safe with Dart’s GC and native memory.

## Platform-Specific Details

- **Android**: Native code is built as part of the Android project; the Dart plugin loads the library via the engine (e.g. `DynamicLibrary.open('libzstandard_android_plugin.so')` or similar as configured).
- **iOS / macOS**: zstd is built as a static library or framework and linked into the app; the plugin opens the corresponding dynamic library or uses the linked symbols as per project setup.
- **Linux**: CMake builds `libzstandard_linux_plugin.so`; the plugin loads it by name.
- **Windows**: CMake builds `zstandard_windows_plugin.dll` (or similar); the plugin loads it by name.

Each platform’s README and `docs/platforms/` guide should describe how to build and where the library is placed.

## Error Handling

- `ZSTD_compress` and `ZSTD_decompress` return negative values on error. The Dart code checks for `result > 0` and returns `null` otherwise (or throws, depending on the package’s public API contract).
- `ZSTD_getFrameContentSize` returns -1 (unknown) or -2 (error). Implementations use a fallback destination size when the frame size is unknown.

## Related Documentation

- [Overview](overview.md)
- [Platform Interface](platform-interface.md)
- [Isolate Pattern](isolate-pattern.md) — Offloading compression/decompression to isolates on native platforms
