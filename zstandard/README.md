[![pub package](https://img.shields.io/pub/v/zstandard.svg)](https://pub.dev/packages/zstandard)

# Zstandard

Zstandard (zstd) is a fast, high-compression algorithm developed by Meta (formerly Facebook) for real-time applications. It offers a broad range of compression levels, supporting both high-speed and high-compression-ratio requirements, making it ideal for data storage, transmission, and backup solutions.

This Flutter plugin provides a native implementation of the zstd compression algorithm. It integrates the zstd library in C through FFI for native platforms (Android, iOS, Windows, macOS, and Linux), ensuring efficient compression and decompression. On the web, it leverages WebAssembly to deliver the same high-performance compression. This plugin enables seamless, cross-platform data compression, suitable for applications needing fast, efficient data processing.

|             |      Android       |        iOS         | [Web](https://flutter.dev/web) | [macOS](https://flutter.dev/desktop) | [Windows](https://flutter.dev/desktop) | [Linux](https://flutter.dev/desktop) | [Fuchsia](https://fuchsia.dev/) |
|:-----------:|:------------------:|:------------------:|:------------------------------:|:------------------------------------:|:--------------------------------------:|:------------------------------------:|:-------------------------------:|
|   Status    | :heavy_check_mark: | :heavy_check_mark: |       :heavy_check_mark:       |          :heavy_check_mark:          |           :heavy_check_mark:           |          :heavy_check_mark:          |                ❌                |
|   Native    |        FFI         |        FFI         |          WebAssembly           |                 FFI                  |                  FFI                   |                 FFI                  |                ❌                |
| Precompiled |         No         |         No         |           Yes (wasm)           |                  No                  |                   No                   |                  No                  |                ❌                 |

> **Note:** The C files for the compression library are sourced from the official [facebook/zstd](https://github.com/facebook/zstd/tree/dev/lib) repository.

> For command-line usage on desktops, refer to the [zstandard_cli](https://pub.dev/packages/zstandard_cli) package.

## Basic Usage

```dart
void act() async {
  final zstandard = Zstandard();

  Uint8List original = Uint8List.fromList([...]);

  Uint8List? compressed = await zstandard.compress(original);
  
  final decompressed = compressed == null
      ? null
      : await zstandard.decompress(compressed);
}
```

With extension functions:

```dart
void act() async {
  Uint8List original = Uint8List.fromList([...]);

  Uint8List? compressed = await original.compress();
  
  final decompressed = await compressed.decompress();
}
```

Compression always emits a valid zstd frame, including for empty input.
Decompression supports concatenated frames and frames without a declared
content size. It returns `null` for malformed or truncated input and limits
output to 256 MiB by default. Pass `maxOutputSize` to `decompress` (including
the extension method) to choose a smaller application-specific budget.

Below are examples of the plugin in action across different platforms.

<p align="center"><img width="50%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_android/images/sample.png"></p>

<p align="center"><img width="50%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_ios/images/sample.png"></p>

<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_macos/images/sample.png"></p>

<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_web/images/sample.png"></p>

<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_windows/images/sample.png"></p>

<p align="center"><img width="90%" vspace="10" src="https://github.com/vypdev/zstandard/raw/master/zstandard_linux/images/sample.png"></p>
