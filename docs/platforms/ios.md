# iOS Platform Guide

The **zstandard_ios** package provides the iOS implementation of the Zstandard Flutter plugin using FFI and the native zstd library.

## Support

| Architecture | Support |
|--------------|---------|
| arm64        | Yes (device) |
| x86_64       | Yes (simulator) |

## Installation

Add the main plugin to your app; the iOS implementation is included via the federated plugin:

```yaml
dependencies:
  zstandard: ^1.3.29
```

No additional setup is required for normal use. The plugin registers the iOS implementation automatically when running on iOS.

## Architecture

- **Native layer**: The facebook/zstd C library lives under `ios/Classes/zstd/` and is built as part of the iOS project (e.g. via CocoaPods or Xcode). It is linked into the app and loaded by the Dart plugin via FFI.
- **Dart layer**: The package uses Dart FFI and generated bindings to call `ZSTD_compress`, `ZSTD_decompress`, `ZSTD_compressBound`, and `ZSTD_getFrameContentSize`.
- **Isolates**: The implementation may use a helper isolate for async compression/decompression to avoid blocking the UI thread.

## Usage

Use the main package API; the iOS implementation is used automatically:

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

If you are developing the zstandard_ios package:

1. The native zstd source is under `zstandard_ios/ios/Classes/zstd/`.
2. The project may use a Podspec and CocoaPods to build the static library or framework.
3. FFI bindings are generated (e.g. with `ffigen`) from the zstd headers.

See the package’s `ios/` directory and the repo’s [Building](development/building.md) guide.

## Testing

- **Unit tests**: From the package directory: `flutter test`
- **Integration tests**: Run the example app on an iOS device or simulator and run `integration_test` (e.g. `flutter test integration_test/` from the example).

## Limitations

- Simulator and device use different architectures; ensure the correct slice is built for the target.
- Very large inputs may use significant memory; consider chunking for very large data.

## Troubleshooting

- **Library or symbol not found**: Ensure the native target is included in your app’s build and that you are building for the correct architecture (simulator vs device).
- **Crashes**: Verify inputs are valid and not null where required; see [Common Issues](../troubleshooting/common-issues.md).

## See Also

- [Architecture — FFI Implementation](../architecture/ffi-implementation.md)
- [Architecture — Isolate Pattern](../architecture/isolate-pattern.md)
- [API — Main](../api/main-api.md)
