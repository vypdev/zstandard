[![pub package](https://img.shields.io/pub/v/zstandard_macos.svg)](https://pub.dev/packages/zstandard_macos)

# zstandard_macos

The macOS implementation of the [zstandard](https://pub.dev/packages/zstandard) Flutter plugin. Uses FFI and the native Zstandard C library.

## Installation

Add the main plugin to your app; this package is included automatically via the federated plugin:

```yaml
dependencies:
  zstandard: ^1.3.29
```

No extra setup is required for normal use.

## Usage

Use the main [zstandard](https://pub.dev/packages/zstandard) API; the macOS implementation is selected automatically on macOS:

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

- **ZstandardMacOS()** — Creates the macOS platform implementation.
- **compress(Uint8List data, int compressionLevel)** — Compresses `data` (level 1–22). Returns compressed bytes or `null`.
- **decompress(Uint8List data)** — Decompresses zstd-compressed data. Returns decompressed bytes or `null`.
- **getPlatformVersion()** — Returns a platform identifier string.

## Architecture

This package uses Dart FFI with the native zstd C library. Swift Package Manager is the primary integration for Flutter 3.44 and newer and statically links the shared target into the app; CocoaPods remains supported for compatibility and embeds the plugin framework. Both paths use the same canonical C implementation from `zstandard_native`. Supports x64 and arm64 (Apple Silicon).

## Testing

From the package directory:

```bash
flutter test
```

Unit tests that use the native library require the framework to be built (e.g. by building the example macOS app first). Tests are skipped when not running on macOS.

## Troubleshooting

- **Swift Package Manager**: Flutter 3.44 and newer enables this path by default.
- **CocoaPods**: For older Flutter projects or explicit compatibility testing, run `flutter config --no-enable-swift-package-manager` and then `pod install` in your app’s `macos/` directory.
- **Library not loaded**: Build your app with `flutter build macos` or run from the macOS runner so the native target is linked. SwiftPM exposes it through the process; CocoaPods embeds the plugin framework.
- **Wrong architecture**: Ensure you are building for the correct target (x64 vs arm64).

See the [documentation](https://github.com/vypdev/zstandard/tree/master/docs) for more.

<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_macos/images/sample.png"></p>
