[![pub package](https://img.shields.io/pub/v/zstandard_ios.svg)](https://pub.dev/packages/zstandard_ios)

# zstandard_ios

The iOS implementation of the [zstandard](https://pub.dev/packages/zstandard) Flutter plugin. Uses FFI and the native Zstandard C library.

## Installation

Add the main plugin to your app; this package is included automatically via the federated plugin:

```yaml
dependencies:
  zstandard: ^1.5.0
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
- **decompressWithOptions(Uint8List data, {int maxOutputSize})** — Decompresses complete, concatenated, or unknown-size zstd frames with a bounded output (256 MiB by default). Invalid, truncated, or oversized input returns `null`.
- **getPlatformVersion()** — Returns a platform identifier string.

## Architecture

This package uses Dart FFI with the native zstd C library. Swift Package
Manager statically links the shared target into the app; CocoaPods remains
supported and embeds the plugin framework. Both paths compile the same
common/compress/decompress source set from `zstandard_native`. Public work runs
in an isolate using Dart-owned bytes and bounded streaming decompression.

## Testing

From the package directory:

```bash
flutter test
```

Unit tests run only on iOS (skipped on other platforms). For integration tests, run the main [zstandard](https://pub.dev/packages/zstandard) example app on an iOS device or simulator.

## Troubleshooting

- **Symbol or framework not found**: Ensure the iOS target is built (e.g. `flutter run -d ios`) and that you are targeting a supported architecture (arm64 device, x86_64/arm64 simulator). SwiftPM loads the statically linked symbols from the process; CocoaPods loads the embedded framework.
- **Swift Package Manager**: Flutter 3.44 and newer enables this path by default.
- **CocoaPods**: For older Flutter projects or explicit compatibility testing, run `flutter config --no-enable-swift-package-manager` and then `pod install` in your app’s `ios/` directory if needed.

See the [documentation](https://github.com/vypdev/zstandard/tree/master/docs) for more.

<p align="center"><img width="50%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_ios/images/sample.png"></p>
