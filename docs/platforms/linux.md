# Linux Platform Guide

The **zstandard_linux** package provides the Linux implementation of the Zstandard Flutter plugin using FFI and the native zstd library.

## Support

| Architecture | Support |
|--------------|---------|
| x64          | Yes |
| arm64        | Yes |

## Installation

Add the main plugin to your app; the Linux implementation is included via the federated plugin:

```yaml
dependencies:
  zstandard: ^1.3.29
```

No additional setup is required for normal use. The plugin registers the Linux implementation automatically when running on Linux.

## Architecture

- **Native layer**: The facebook/zstd C library is built with CMake (e.g. under `linux/` or `src/`) and produces a shared library `libzstandard_linux_plugin.so` that the Dart plugin loads via FFI.
- **Dart layer**: The package uses Dart FFI and generated bindings to call `ZSTD_compress`, `ZSTD_decompress`, `ZSTD_compressBound`, and `ZSTD_getFrameContentSize`.
- **Isolates**: The implementation may use a helper isolate for async compression/decompression.

## Usage

Use the main package API; the Linux implementation is used automatically:

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

## Building the Native Library

If you are developing the zstandard_linux package:

1. The native zstd source is under the package’s `src/`; the Linux build is typically under `linux/` using CMake.
2. CMake builds the shared library (e.g. `libzstandard_linux_plugin.so`).
3. FFI bindings are generated (e.g. with `ffigen`) from the zstd headers.

See the package’s `linux/` and `src/` directories and the repo’s [Building](development/building.md) guide.

## Testing

- **Unit tests**: From the package directory: `flutter test`
- **Integration tests**: Run the example Linux app and execute `integration_test` from the example.

## Performance characteristics

- **Compression/decompression**: Typically runs in a background isolate so the UI thread is not blocked.
- **Memory**: Allocations scale with input and output size; high compression levels (19–22) use more memory.
- **Throughput**: Similar to native zstd; level 1–3 are fastest, level 22 slowest. Depends on host CPU.

## Known limitations

- Only Linux is supported; for other platforms use the corresponding platform package.
- Very large inputs may use significant memory; consider chunking (see [Advanced usage](../guides/advanced-usage.md)).
- The shared library must be on the library path (e.g. next to the executable or `LD_LIBRARY_PATH`) when the app runs.

## Troubleshooting

- **libzstandard_linux_plugin.so not found**: Ensure the .so is built and available in the library path when the app runs (e.g. same directory as the executable or `LD_LIBRARY_PATH`). Build with `flutter build linux` or run from the IDE.
- **Crashes**: Verify inputs and null safety; see [Common Issues](../troubleshooting/common-issues.md).

## See Also

- [Architecture — FFI Implementation](../architecture/ffi-implementation.md)
- [Architecture — Isolate Pattern](../architecture/isolate-pattern.md)
- [API — Main](../api/main-api.md)
