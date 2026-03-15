# Windows Platform Guide

The **zstandard_windows** package provides the Windows implementation of the Zstandard Flutter plugin using FFI and the native zstd library.

## Support

| Architecture | Support |
|--------------|---------|
| x64          | Yes |
| arm64        | Yes |

## Installation

Add the main plugin to your app; the Windows implementation is included via the federated plugin:

```yaml
dependencies:
  zstandard: ^1.3.29
```

No additional setup is required for normal use. The plugin registers the Windows implementation automatically when running on Windows.

## Architecture

- **Native layer**: The facebook/zstd C library is built with CMake under the package’s `windows/` (or `src/`) and produces a DLL (e.g. `zstandard_windows_plugin.dll`) that the Dart plugin loads via FFI.
- **Dart layer**: The package uses Dart FFI and generated bindings to call `ZSTD_compress`, `ZSTD_decompress`, `ZSTD_compressBound`, and `ZSTD_getFrameContentSize`.
- **Isolates**: The implementation may use a helper isolate for async compression/decompression.

## Usage

Use the main package API; the Windows implementation is used automatically:

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

If you are developing the zstandard_windows package:

1. The native zstd source is under the package’s `src/` (or equivalent); the Windows build is typically under `windows/`.
2. CMake is used to build the zstd library and the plugin DLL.
3. FFI bindings are generated (e.g. with `ffigen`) from the zstd headers.

See the package’s `windows/` and `src/` directories and the repo’s [Building](development/building.md) guide.

## Testing

- **Unit tests**: From the package directory: `flutter test`
- **Integration tests**: Run the example Windows app and execute `integration_test` from the example.

## Performance characteristics

- **Compression/decompression**: Typically runs in a background isolate.
- **Memory**: Scales with input and output size; high levels use more memory.
- **Throughput**: Level 1–3 fastest; level 22 slowest. Supports x64 and ARM64.

## Known limitations

- Only Windows is supported; for other platforms use the corresponding platform package.
- Very large inputs may use significant memory; consider chunking (see [Advanced usage](../guides/advanced-usage.md)).
- The DLL must be next to the executable or on the path when the app runs.

## Troubleshooting

- **DLL not found**: Ensure the DLL is built and placed where the plugin expects it (e.g. next to the executable or in a known path). Build the Windows app with `flutter build windows` or run from the IDE.
- **Crashes**: Verify inputs and null safety; see [Common Issues](../troubleshooting/common-issues.md).

## See Also

- [Architecture — FFI Implementation](../architecture/ffi-implementation.md)
- [Architecture — Isolate Pattern](../architecture/isolate-pattern.md)
- [API — Main](../api/main-api.md)
