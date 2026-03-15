# Android Platform Guide

The **zstandard_android** package provides the Android implementation of the Zstandard Flutter plugin using FFI and the native zstd library.

## Support

| Architecture | Support |
|--------------|---------|
| armeabi-v7a  | As per Flutter/Android |
| arm64-v8a    | Yes |
| x86_64       | Yes (e.g. emulators) |

## Installation

Add the main plugin to your app; the Android implementation is included via the federated plugin:

```yaml
dependencies:
  zstandard: ^1.3.29
```

No additional Gradle or native setup is required for normal use. The plugin registers the Android implementation automatically when running on Android.

## Architecture

- **Native layer**: The facebook/zstd C library is built as part of the Android project (e.g. via CMake or Android NDK) and exposed as a shared library (e.g. `libzstandard_android_plugin.so`).
- **Dart layer**: The package uses Dart FFI to open the library and generated bindings to call `ZSTD_compress`, `ZSTD_decompress`, `ZSTD_compressBound`, and `ZSTD_getFrameContentSize`.
- **Isolates**: The implementation may use a helper isolate for async compression/decompression to avoid blocking the UI thread.

## Usage

Use the main package API; the Android implementation is used automatically:

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

If you are developing or modifying the zstandard_android package:

1. The native zstd source is under `zstandard_android/src/` (or the project’s native path).
2. The Android build (e.g. `android/build.gradle`, CMake) compiles zstd and produces the shared library.
3. FFI bindings are generated (e.g. with `ffigen`) from the zstd headers and committed or generated at build time.

See the package’s `android/` and `src/` directories and the main repo’s [Building](development/building.md) guide.

## Testing

- **Unit tests**: Run from the package directory: `flutter test`
- **Integration tests**: Use the example app: run the app on an Android device or emulator and execute `integration_test` (e.g. `flutter test integration_test/` from the example).

## Limitations

- Requires a device/emulator with the supported ABI; otherwise the native library may fail to load.
- Very large inputs may use significant memory (input + output buffers); consider chunking for very large data.

## Troubleshooting

- **Library not found**: Ensure you are running on a supported ABI and that the plugin’s native library is built and packaged (e.g. `flutter build apk` or run from IDE).
- **Crashes on compress/decompress**: Check that input is valid and that you are not passing null where `Uint8List` is required; check [Common Issues](../troubleshooting/common-issues.md).

## See Also

- [Architecture — FFI Implementation](../architecture/ffi-implementation.md)
- [Architecture — Isolate Pattern](../architecture/isolate-pattern.md)
- [API — Main](../api/main-api.md)
