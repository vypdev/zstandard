# macOS Platform Guide

The **zstandard_macos** package provides the macOS implementation of the Zstandard Flutter plugin using FFI and the native zstd library.

## Support

| Architecture | Support |
|--------------|---------|
| x64          | Yes |
| arm64        | Yes (Apple Silicon) |

## Installation

Add the main plugin to your app; the macOS implementation is included via the federated plugin:

```yaml
dependencies:
  zstandard: ^1.3.29
```

No additional setup is required for normal use. The plugin registers the macOS implementation automatically when running on macOS.

## Architecture

- **Native layer**: The facebook/zstd C library is built from source under the package’s `src/` (or equivalent) and produced as a framework or dynamic library that the Dart plugin loads via FFI.
- **Dart layer**: The package uses Dart FFI and generated bindings to call `ZSTD_compress`, `ZSTD_decompress`, `ZSTD_compressBound`, and `ZSTD_getFrameContentSize`.
- **Isolates**: The implementation may use a helper isolate for async compression/decompression.

## Usage

Use the main package API; the macOS implementation is used automatically:

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

If you are developing the zstandard_macos package:

1. The native zstd source is under the package’s `src/` directory.
2. The macOS build (e.g. CocoaPods, Xcode) compiles zstd and produces the framework or dylib.
3. FFI bindings are generated (e.g. with `ffigen`) from the zstd headers.

See the package’s build configuration and the repo’s [Building](development/building.md) guide.

## Testing

- **Unit tests**: From the package directory: `flutter test`
- **Integration tests**: Run the example macOS app and execute `integration_test` from the example.

## Limitations

- Only macOS is supported; for other platforms use the corresponding platform package.
- Very large inputs may use significant memory; consider chunking for very large data.

## Troubleshooting

- **Library not found**: Ensure the native library/framework is built and linked for the current architecture (x64 vs arm64).
- **Crashes**: Verify inputs and null safety; see [Common Issues](../troubleshooting/common-issues.md).

## See Also

- [Architecture — FFI Implementation](../architecture/ffi-implementation.md)
- [Architecture — Isolate Pattern](../architecture/isolate-pattern.md)
- [API — Main](../api/main-api.md)
