# CLI API Reference

`package:zstandard_cli/zstandard_cli.dart` provides a pure-Dart desktop API
for macOS, Windows, and Linux. It bundles x64 and arm64 native libraries.

## Dart API

```dart
final codec = ZstandardCLI();

Future<Uint8List?> compress(
  Uint8List data, {
  int compressionLevel = 3,
})

Future<Uint8List?> decompress(
  Uint8List data, {
  int maxOutputSize = 256 * 1024 * 1024,
})
```

Compression accepts levels 1–22 and emits a valid frame for empty input.
Decompression is streaming, supports unknown-size and concatenated frames,
and returns `null` for invalid, truncated, or oversized input. The equivalent
options are available on the `Uint8List?` extensions.

`getPlatformVersion()` returns a diagnostic OS string.

## Command-line entry points

```text
zstandard-compress [options] <input|->
  -l, --level LEVEL
  -o, --output PATH
  -f, --force

zstandard-decompress [options] <input|->
  -m, --max-output-size BYTES
  -o, --output PATH
  -f, --force
```

Both commands also accept `--help` and `--version`. `-` reads stdin; without
an explicit output, stdin writes to stdout. Compression appends `.zstd` to a
file name. Decompression strips `.zstd`, or appends `.out` when there is no
matching suffix. Input aliases are never overwritten, and existing output
files require `--force`.

Exit codes are 0 (success), 1 (I/O or codec failure), and 2 (usage error or
refused overwrite).

The native library path is resolved from the package URI rather than the
working directory. Set `ZSTANDARD_CLI_LIBRARY` to an explicit library path for
custom deployment or testing.

See the [CLI platform guide](../platforms/cli.md).
