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

- **Native layer**: The canonical facebook/zstd C library lives in `zstandard_native/src/zstd/`. Swift Package Manager consumes the shared `zstandard-native` product exposed by the repository-level `Package.swift`; CocoaPods uses an ignored generated copy. The resulting framework is loaded by the Dart plugin via FFI.
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

1. The canonical zstd source is at `zstandard_native/src/zstd/`; do not copy or edit it in the iOS package.
2. The project supports CocoaPods through the podspec and Swift Package Manager through `ios/zstandard_ios/Package.swift`, which depends on the shared `zstandard-native` product.
3. FFI bindings are generated (e.g. with `ffigen`) from the zstd headers.

The CocoaPods copy is generated under `ios/Classes/zstd/`, ignored by Git, and excludes the SwiftPM-only public-header bridge and `module.modulemap`; iOS builds define `ZSTD_DISABLE_ASM` for compatibility. Update `zstandard_native/src/zstd/` and let the podspec refresh the copy.

To validate Swift Package Manager integration, run `flutter config --enable-swift-package-manager`, then `flutter build ios --no-codesign`.

See the package’s `ios/` directory and the repo’s [Building](development/building.md) guide.

## Testing

- **Unit tests**: From the package directory: `flutter test`
- **Integration tests**: Run the example app on an iOS device or simulator and run `integration_test` (e.g. `flutter test integration_test/` from the example).

## Performance characteristics

- **Compression/decompression**: Runs on a background isolate so the UI thread stays responsive.
- **Memory**: Peak usage scales with input and output size; high levels (19–22) use more memory.
- **Throughput**: Level 1–3 are fastest; level 22 is slowest. Assembly is disabled in the iOS build for compatibility.

## Known limitations

- Simulator and device use different architectures; ensure the correct slice is built for the target.
- Very large inputs may use significant memory; consider chunking (see [Advanced usage](../guides/advanced-usage.md)).
- Static linking only; no dynamic zstd loading.

## Troubleshooting

- **Library or symbol not found**: Ensure the native target is included in your app’s build and that you are building for the correct architecture (simulator vs device).
- **Crashes**: Verify inputs are valid and not null where required; see [Common Issues](../troubleshooting/common-issues.md).

## See Also

- [Architecture — FFI Implementation](../architecture/ffi-implementation.md)
- [Architecture — Isolate Pattern](../architecture/isolate-pattern.md)
- [API — Main](../api/main-api.md)
