# CLI API Reference

The **zstandard_cli** package provides Zstandard compression and decompression for **pure Dart** applications targeting **macOS, Windows, and Linux** (no Flutter). It uses FFI with precompiled native zstd libraries.

## Import

```dart
import 'package:zstandard_cli/zstandard_cli.dart';
```

## ZstandardCLI Class

### Constructor

```dart
ZstandardCLI()
```

Creates a new instance. Each instance shares the same underlying native library (loaded once per process).

### getPlatformVersion

```dart
Future<String?> getPlatformVersion()
```

Returns a string describing the current platform (e.g. `"macOS 14.0"`, `"Windows 10"`, `"Linux ..."`). Useful for CLI output or debugging.

### compress

```dart
Future<Uint8List?> compress(Uint8List data, {int compressionLevel = 3})
```

Compresses `data` using Zstandard.

- **data**: Bytes to compress. Empty input returns the same empty `Uint8List` as per implementation.
- **compressionLevel**: Optional; default **3**. Range 1–22.
- **Returns**: Compressed bytes, or `null` on failure.

### decompress

```dart
Future<Uint8List?> decompress(Uint8List data)
```

Decompresses Zstandard-compressed `data`.

- **data**: Compressed bytes (full zstd frame).
- **Returns**: Decompressed bytes, or `null` on failure.

---

## Extensions (zstandard_cli)

The package also defines **ZstandardExt** on `Uint8List?`:

### compress

```dart
Future<Uint8List?> compress({int compressionLevel = 3})
```

Same as `ZstandardCLI().compress(this, compressionLevel: compressionLevel)`. Returns `null` if the receiver is `null`.

### decompress

```dart
Future<Uint8List?> decompress()
```

Same as `ZstandardCLI().decompress(this)`. Returns `null` if the receiver is `null`.

**Example:**

```dart
final data = Uint8List.fromList([1, 2, 3, 4, 5]);
final compressed = await data.compress(compressionLevel: 5);
final decompressed = await compressed?.decompress();
```

## Command-Line Entry Points

When used as a CLI (e.g. `dart run zstandard_cli:compress` / `zstandard_cli:decompress`), the package provides:

- **compress**: Reads a file (or stdin), compresses with a given level, writes to file (or stdout). Usage: `dart run zstandard_cli:compress <file> <level>`.
- **decompress**: Reads a compressed file, decompresses, writes output. Usage: `dart run zstandard_cli:decompress <file.zstd>`.

See the package README and [Platforms — CLI](../platforms/cli.md) for exact usage and file naming.

## Platform Support

| Platform | Architectures | Precompiled library |
|----------|----------------|----------------------|
| macOS    | x64, arm64     | Yes                  |
| Windows  | x64, arm64     | Yes                  |
| Linux    | x64, arm64     | Yes                  |

The library is loaded at runtime from the package’s resources based on the current platform and architecture.

## See Also

- [Platforms — CLI](../platforms/cli.md)
- [Main API](main-api.md) — Flutter plugin API
