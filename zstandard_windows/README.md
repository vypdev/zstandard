[![pub package](https://img.shields.io/pub/v/zstandard_windows.svg)](https://pub.dev/packages/zstandard_windows)

# zstandard_windows

The Windows implementation of the [zstandard](https://pub.dev/packages/zstandard) Flutter plugin. Uses FFI and the native Zstandard C library.

## Installation

Add the main plugin to your app; this package is included automatically via the federated plugin:

```yaml
dependencies:
  zstandard: ^1.3.29
```

No extra setup is required for normal use.

## Usage

Use the main [zstandard](https://pub.dev/packages/zstandard) API; the Windows implementation is selected automatically on Windows:

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

- **ZstandardWindows()** — Creates the Windows platform implementation.
- **compress(Uint8List data, int compressionLevel)** — Compresses `data` (level 1–22). Returns compressed bytes or `null`.
- **decompress(Uint8List data)** — Decompresses zstd-compressed data. Returns decompressed bytes or `null`.
- **getPlatformVersion()** — Returns a platform identifier string.

## Architecture

This package uses Dart FFI to load `zstandard_windows.dll` and call the Zstandard C API. The DLL is built by CMake when you build your Flutter Windows app. Supports x64 and arm64.

## Testing

From the package directory:

```bash
flutter test
```

Unit tests run only on Windows (skipped on other platforms). For integration tests, run the main [zstandard](https://pub.dev/packages/zstandard) example app on Windows.

## Troubleshooting

- **DLL not found**: Build your app with `flutter build windows` or run from the Flutter Windows runner so the native library is built and placed next to the executable.
- **Wrong architecture**: Build for the correct target (x64 or arm64).

See the [documentation](https://github.com/landamessenger/zstandard/tree/master/docs) for more.

<p align="center"><img width="90%" vspace="10" src="https://github.com/landamessenger/zstandard/raw/master/zstandard_windows/images/sample.png"></p>
