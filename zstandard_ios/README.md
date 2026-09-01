[![pub package](https://img.shields.io/pub/v/zstandard_ios.svg)](https://pub.dev/packages/zstandard_ios)

# zstandard_ios

The iOS implementation of the [zstandard](https://pub.dev/packages/zstandard) Flutter plugin. Uses FFI and the native Zstandard C library.

## Installation

Add the main plugin to your app; this package is included automatically via the federated plugin:

```yaml
dependencies:
  zstandard: ^1.3.29
```

No extra setup is required for normal use.

## Usage

Use the main [zstandard](https://pub.dev/packages/zstandard) API; the iOS implementation is selected automatically on iOS:

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

- **ZstandardIOS()** — Creates the iOS platform implementation.
- **compress(Uint8List data, int compressionLevel)** — Compresses `data` (level 1–22). Returns compressed bytes or `null`.
- **decompress(Uint8List data)** — Decompresses zstd-compressed data. Returns decompressed bytes or `null`.
- **getPlatformVersion()** — Returns a platform identifier string.

## Architecture

This package uses Dart FFI with the zstandard_ios framework (native zstd C library). The framework is built as part of your iOS app when you build or run from Xcode or Flutter.

## Swift Package Manager

The plugin supports Swift Package Manager through the manifest at `ios/zstandard_ios/Package.swift`. Flutter uses this package when Swift Package Manager is enabled for iOS; CocoaPods remains supported for projects using the default dependency manager.

Swift Package Manager gets the `zstandard-native` product from the repository-level package, whose target path is the canonical `zstandard_native/src/zstd/`. The plugin does not carry a second C source tree. CocoaPods refreshes an ignored copy under `ios/Classes/zstd/` at install/build time; run `scripts/sync_zstd.sh` manually only when diagnosing a CocoaPods build.

## Testing

From the package directory:

```bash
flutter test
```

Unit tests run only on iOS (skipped on other platforms). For integration tests, run the main [zstandard](https://pub.dev/packages/zstandard) example app on an iOS device or simulator.

## Troubleshooting

- **Symbol or framework not found**: Ensure the iOS target is built (e.g. `flutter run -d ios`) and that you are targeting a supported architecture (arm64 device, x86_64/arm64 simulator).
- **CocoaPods**: Run `pod install` in your app’s `ios/` directory if needed.

See the [documentation](https://github.com/vypdev/zstandard/tree/master/docs) for more.

<p align="center"><img width="50%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_ios/images/sample.png"></p>
