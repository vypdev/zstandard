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

- **Native layer**: The canonical facebook/zstd C library lives in `zstandard_native/src/zstd/`. The macOS podspec synchronizes it into the generated `macos/Classes/zstd/` directory at pod install/build time and builds it as part of the CocoaPods target, producing a framework that the Dart plugin loads via FFI.
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

1. The canonical zstd source is at `zstandard_native/src/zstd/`; the podspec syncs it into the generated `macos/Classes/zstd/` directory at install/build time.
2. The macOS build (CocoaPods/Xcode) compiles zstd from `Classes/zstd/` and produces the framework.
3. FFI bindings are generated (e.g. with `ffigen`) from the zstd headers.

The generated source directory is retained after the build so the Xcode build system cannot delete files while compiling them. It is ignored by Git and must not be edited directly; update `zstandard_native/src/zstd/` instead.

See the package’s build configuration and the repo’s [Building](development/building.md) guide.
See also the [Apple Dependency Strategy](../development/apple-dependencies.md).

## Testing

- **Unit tests**: From the package directory: `flutter test`
- **Integration tests**: Run the example macOS app and execute `integration_test` from the example.

## Performance characteristics

- **Compression/decompression**: Typically runs in a background isolate.
- **Memory**: Proportional to input and output; lower levels use less memory.
- **Throughput**: Level 1–3 fastest; level 22 slowest. Supports both Intel and Apple Silicon.

## Known limitations

- Only macOS is supported; for other platforms use the corresponding platform package.
- Very large inputs may use significant memory; consider chunking (see [Advanced usage](../guides/advanced-usage.md)).
- The native library must be built for the current architecture (x64 or arm64) or as a universal binary.

## Troubleshooting

- **Library not found**: Ensure the native library/framework is built and linked for the current architecture (x64 vs arm64).
- **Crashes**: Verify inputs and null safety; see [Common Issues](../troubleshooting/common-issues.md).

## See Also

- [Architecture — FFI Implementation](../architecture/ffi-implementation.md)
- [Architecture — Isolate Pattern](../architecture/isolate-pattern.md)
- [API — Main](../api/main-api.md)
