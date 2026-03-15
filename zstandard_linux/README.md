[![pub package](https://img.shields.io/pub/v/zstandard_linux.svg)](https://pub.dev/packages/zstandard_linux)

# zstandard_linux

The Linux implementation of the [zstandard](https://pub.dev/packages/zstandard) Flutter plugin. Uses FFI and the native Zstandard C library.

## Installation

Add the main plugin to your app; this package is included automatically via the federated plugin:

```yaml
dependencies:
  zstandard: ^1.3.29
```

No extra setup is required for normal use.

## Usage

Use the main [zstandard](https://pub.dev/packages/zstandard) API; the Linux implementation is selected automatically on Linux:

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

- **ZstandardLinux()** — Creates the Linux platform implementation.
- **compress(Uint8List data, int compressionLevel)** — Compresses `data` (level 1–22). Returns compressed bytes or `null`.
- **decompress(Uint8List data)** — Decompresses zstd-compressed data. Returns decompressed bytes or `null`.
- **getPlatformVersion()** — Returns a platform identifier string.

## Architecture

This package uses Dart FFI to load `libzstandard_linux_plugin.so` and call the Zstandard C API. The native library is built by CMake when you build your Flutter Linux app.

## Testing

From the package directory:

```bash
flutter test
```

Unit tests run only on Linux (skipped on other platforms). For integration tests, run the main [zstandard](https://pub.dev/packages/zstandard) example app on Linux.

## Troubleshooting

- **libzstandard_linux_plugin.so not found**: Build your app with `flutter build linux` or run from the Flutter Linux runner so the native library is built and available.
- **Crashes**: Verify inputs and that you are on a supported architecture (x64 or arm64).

See the [documentation](https://github.com/landamessenger/zstandard/tree/master/docs) for more.

<p align="center"><img width="90%" vspace="10" src="https://github.com/landamessenger/zstandard/raw/master/zstandard_linux/images/sample.png"></p>
