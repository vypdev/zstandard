[![pub package](https://img.shields.io/pub/v/zstandard_android.svg)](https://pub.dev/packages/zstandard_android)

# zstandard_android

The Android implementation of the [zstandard](https://pub.dev/packages/zstandard) Flutter plugin. Uses FFI and the native Zstandard C library.

## Installation

Add the main plugin to your app; this package is included automatically via the federated plugin:

```yaml
dependencies:
  zstandard: ^1.3.29
```

No extra Gradle or native setup is required for normal use.

## Usage

Use the main [zstandard](https://pub.dev/packages/zstandard) API; the Android implementation is selected automatically on Android:

```dart
import 'package:zstandard/zstandard.dart';

void main() async {
  final zstandard = Zstandard();
  final data = Uint8List.fromList([1, 2, 3, 4, 5]);

  final compressed = await zstandard.compress(data, 3);
  final decompressed = await zstandard.decompress(compressed ?? Uint8List(0));
}
```

Or use the extension methods:

```dart
final compressed = await data.compress(compressionLevel: 3);
final decompressed = await compressed?.decompress();
```

## API

- **ZstandardAndroid()** — Creates the Android platform implementation.
- **compress(Uint8List data, int compressionLevel)** — Compresses `data` (level 1–22). Returns compressed bytes or `null`.
- **decompress(Uint8List data)** — Decompresses zstd-compressed data. Returns decompressed bytes or `null`.
- **getPlatformVersion()** — Returns a platform identifier string.

## Architecture

This package uses Dart FFI to load `libzstandard_android.so` and call the Zstandard C API (`ZSTD_compress`, `ZSTD_decompress`, `ZSTD_compressBound`, `ZSTD_getFrameContentSize`). Heavy work may run in a background isolate to keep the UI responsive.

## Testing

From the package directory:

```bash
flutter test
```

Unit tests run only on Android (they are skipped on other platforms). For full integration tests, run the main [zstandard](https://pub.dev/packages/zstandard) example app on an Android device or emulator.

## Troubleshooting

- **Library not found**: Ensure you build and run the app for Android (e.g. `flutter run` or `flutter build apk`) so the native library is compiled and packaged.
- **Crashes**: Verify inputs are non-null and valid; for decompress, ensure the data is a valid zstd frame.

See the [documentation](https://github.com/vypdev/zstandard/tree/master/docs) for more.

<p align="center"><img width="50%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_android/images/sample.png"></p>
