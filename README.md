[![pub package](https://img.shields.io/pub/v/zstandard.svg)](https://pub.dev/packages/zstandard)  
[![pub package](https://img.shields.io/pub/v/zstandard_cli.svg)](https://pub.dev/packages/zstandard_cli)  
[![codecov](https://codecov.io/gh/vypdev/zstandard/graph/badge.svg)](https://codecov.io/gh/vypdev/zstandard)

# Zstandard

Zstandard (zstd) is a fast, high-compression algorithm developed by Meta (formerly Facebook) designed for real-time compression scenarios. It offers a flexible range of compression levels, allowing both high-speed and high-ratio compression, making it ideal for applications with diverse performance needs. Zstandard is widely used in data storage, transmission, and backup solutions.

This repository contains a federated Flutter plugin and a CLI package for `zstandard` compression, enabling both in-app and command-line usage. The two main components are:

- **[zstandard](https://pub.dev/packages/zstandard):** A Flutter plugin for cross-platform compression, supporting mobile, desktop, and web platforms. This package integrates the zstd library through FFI for native platforms and WebAssembly for the web, allowing efficient data compression in any Flutter environment.

- **[zstandard_cli](https://pub.dev/packages/zstandard_cli):** A pure Dart package providing CLI capabilities for macOS, Windows, and Linux. It enables command-line compression and decompression for data files and streams.

Native platform packages and the CLI share the zstd C source and FFI bindings via the **[zstandard_native](https://github.com/vypdev/zstandard/tree/master/zstandard_native)** package (`zstandard_native/src/zstd/`), so a single copy is used whether you depend on the plugin from the repo or from pub.dev.

---

## Compatibility

|             | [Android](https://flutter.dev) | [iOS](https://developer.apple.com/ios/) | [Web](https://flutter.dev/web) | [macOS](https://flutter.dev/desktop) | [Windows](https://flutter.dev/desktop) | [Linux](https://flutter.dev/desktop) | [Fuchsia](https://fuchsia.dev/) |
|:-----------:|:------------------------------:|:--------------------------------------:|:-------------------------------------:|:------------------------------------:|:--------------------------------------:|:------------------------------------:|:-------------------------------:|
|   Flutter   |       :heavy_check_mark:       |           :heavy_check_mark:           |       :heavy_check_mark: (wasm)       |          :heavy_check_mark:          |           :heavy_check_mark:           |          :heavy_check_mark:          |                ❌                |
|   Native    |               FFI              |                  FFI                   |             WebAssembly              |                 FFI                  |                  FFI                   |                 FFI                  |                ❌                |
| Precompiled |               No               |                  No                    |                   Yes                |                  No                  |                   No                   |                 No                   |                ❌                |

|             | [macOS](https://flutter.dev/desktop) | [Windows](https://flutter.dev/desktop) | [Linux](https://flutter.dev/desktop) |
|:-----------:|:------------------------------------:|:--------------------------------------:|:------------------------------------:|
|     x64     |          :heavy_check_mark:          |           :heavy_check_mark:           |          :heavy_check_mark:          |
|    arm64    |      :heavy_check_mark:              |           :heavy_check_mark:           |       :heavy_check_mark:             |
| Precompiled |                 Yes                  |                  Yes                   |                 Yes                  |

---

## Documentation

Full documentation is in the [**docs/**](docs/README.md) directory, including:

- [Getting started](docs/guides/getting-started.md)
- [Architecture](docs/architecture/overview.md)
- [API reference](docs/api/main-api.md)
- [Platform guides](docs/platforms/)
- [Development and contributing](docs/development/CONTRIBUTING.md)
- [Troubleshooting](docs/troubleshooting/common-issues.md)

---

## Basic Usage

### In-App (Flutter)

```dart
import 'package:zstandard/zstandard.dart';

void main() async {
  final zstandard = Zstandard();

  Uint8List originalData = Uint8List.fromList([...]);

  Uint8List? compressed = await zstandard.compress(originalData);
  
  Uint8List? decompressed = await zstandard.decompress(compressed ?? Uint8List(0));
}
```

Using extensions:

```dart
import 'package:zstandard/zstandard.dart';

void main() async {
  Uint8List originalData = Uint8List.fromList([...]);

  Uint8List? compressed = await originalData.compress();
  
  Uint8List? decompressed = await compressed.decompress();
}
```

### Command Line (zstandard_cli)

```bash
# Compress a file with a specified compression level
dart run zstandard_cli:compress myfile.txt 3

# Decompress a file
dart run zstandard_cli:decompress myfile.txt.zstd
```

#### Dart Code Example (CLI)

```dart
import 'package:zstandard_cli/zstandard_cli.dart';

void main() async {
  var cli = ZstandardCLI();

  final originalData = Uint8List.fromList([...]);

  final compressed = await cli.compress(originalData, compressionLevel: 3);

  final decompressed = await cli.decompress(compressed ?? Uint8List(0));
}
```

Using extensions in Dart:

```dart
import 'package:zstandard_cli/zstandard_cli.dart';

void main() async {
  final originalData = Uint8List.fromList([...]);

  final compressed = await originalData.compress(compressionLevel: 3);

  final decompressed = await compressed.decompress();
}
```

---

## Screenshots

### Compression and Decompression Samples

#### macOS

<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_cli/images/macos_compression_sample.png"></p>
<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_cli/images/macos_decompression_sample.png"></p>

#### Windows

<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_cli/images/windows_compression_sample.png"></p>
<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_cli/images/windows_decompression_sample.png"></p>

#### Linux

<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_cli/images/linux_compression_sample.png"></p>
<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_cli/images/linux_decompression_sample.png"></p>

#### Flutter Plugin (Android, iOS, macOS, Web, Windows, Linux)

<p align="center"><img width="50%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_android/images/sample.png"></p>
<p align="center"><img width="50%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_ios/images/sample.png"></p>
<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_macos/images/sample.png"></p>
<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_web/images/sample.png"></p>
<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_windows/images/sample.png"></p>
<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_linux/images/sample.png"></p>

---

## License

This project uses code from the original [facebook/zstd](https://github.com/facebook/zstd/tree/dev/lib) repository. Please see the LICENSE file for more information.