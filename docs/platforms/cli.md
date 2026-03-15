# CLI Platform Guide

The **zstandard_cli** package provides Zstandard compression and decompression for **pure Dart** applications (no Flutter) on **macOS, Windows, and Linux**. It uses FFI with precompiled native zstd libraries and supports both in-code API and command-line entry points.

## Support

| Platform | x64 | arm64 | Precompiled |
|----------|-----|-------|-------------|
| macOS    | Yes | Yes   | Yes         |
| Windows  | Yes | Yes   | Yes         |
| Linux    | Yes | Yes   | Yes         |

## Installation

Add the package to your Dart project (not Flutter):

```yaml
dependencies:
  zstandard_cli: ^1.3.29
```

## Usage in Code

```dart
import 'package:zstandard_cli/zstandard_cli.dart';

void main() async {
  final cli = ZstandardCLI();
  final data = Uint8List.fromList([1, 2, 3, 4, 5]);

  final compressed = await cli.compress(data, compressionLevel: 3);
  final decompressed = await cli.decompress(compressed ?? Uint8List(0));
}
```

With extensions:

```dart
final compressed = await data.compress(compressionLevel: 3);
final decompressed = await compressed?.decompress();
```

## Command-Line Usage

Compress a file with a given compression level:

```bash
dart run zstandard_cli:compress <input_file> <compression_level>
```

Example: `dart run zstandard_cli:compress myfile.txt 3`

Decompress a file:

```bash
dart run zstandard_cli:decompress <compressed_file>
```

Example: `dart run zstandard_cli:decompress myfile.txt.zstd`

Output file names and default paths are defined by the package (e.g. compressed files may get a `.zstd` suffix). See the package README for exact behavior.

## Architecture

- **Precompiled libraries**: The package ships with native zstd libraries per platform/architecture (e.g. in `lib/src/bin/` or similar). At runtime, the correct library is loaded based on the current platform and CPU architecture.
- **FFI**: Dart opens the library with `DynamicLibrary` and uses generated bindings to call `ZSTD_compress`, `ZSTD_decompress`, `ZSTD_compressBound`, and `ZSTD_getFrameContentSize`.
- **No Flutter**: No dependency on Flutter; suitable for server or CLI Dart apps.

## API Summary

- **ZstandardCLI()** — Create an instance.
- **compress(Uint8List data, {int compressionLevel = 3})** — Compress; returns `Future<Uint8List?>`.
- **decompress(Uint8List data)** — Decompress; returns `Future<Uint8List?>`.
- **getPlatformVersion()** — Returns a string like `"macOS 14.0"` or `"Linux ..."`.
- **Extensions** on `Uint8List?`: `compress({int compressionLevel = 3})`, `decompress()`.

See [CLI API Reference](../api/cli-api.md) for full details.

## Testing

From the package directory:

```bash
dart test
```

The package has a solid set of unit tests (small/large/empty data, compression levels, roundtrip). Run them on the target platform to ensure the native library loads and behaves correctly.

## Performance characteristics

- **No isolates**: Runs in the current isolate; suitable for CLI or server where blocking is acceptable.
- **Throughput**: Comparable to native zstd; level 1–3 fastest, level 22 slowest.
- **Memory**: Proportional to input and output; precompiled libs are built with standard zstd options.

## Known limitations

- **Desktop only**: macOS, Windows, Linux. For mobile or web, use the main **zstandard** Flutter plugin.
- **Precompiled binaries**: You depend on the package’s shipped libraries; for custom builds or other platforms you would need to build and load your own library (see [Building](development/building.md) and `scripts/build_*.sh`).

## Troubleshooting

- **Library not found**: Ensure you are on a supported platform and architecture. Check that the package’s native library for that platform/arch is present and that `openZstdLibrary()` (or equivalent) can find it.
- **Compress/decompress returns null**: Check that input is valid (e.g. non-empty for cases where the implementation requires it, valid zstd frame for decompress). See [Common Issues](../troubleshooting/common-issues.md).

## See Also

- [API — CLI](../api/cli-api.md)
- [Architecture — FFI Implementation](../architecture/ffi-implementation.md)
