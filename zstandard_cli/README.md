[![pub package](https://img.shields.io/pub/v/zstandard_cli.svg)](https://pub.dev/packages/zstandard_cli)

# zstandard_cli

Pure-Dart Zstandard API and command-line tools for macOS, Windows, and Linux,
with bundled native libraries for x64 and arm64.

## Dart API

```dart
final codec = ZstandardCLI();
final compressed = await codec.compress(data, compressionLevel: 3);
final decompressed = compressed == null
    ? null
    : await codec.decompress(
        compressed,
        maxOutputSize: 64 * 1024 * 1024,
      );
```

The `Uint8List?` extensions expose the same `compress` and `decompress`
options. Compression levels are 1–22 and empty input produces a valid frame.
Decompression supports concatenated frames and frames without a declared
content size. It returns `null` on failure and enforces a 256 MiB output limit
by default.

## Command line

After `dart pub global activate zstandard_cli`, use the installed executables:

```bash
zstandard-compress --level 5 input.bin
zstandard-decompress input.bin.zstd
```

The same commands can be run from a package checkout:

```bash
dart run zstandard_cli:compress --level 5 input.bin
dart run zstandard_cli:decompress input.bin.zstd
```

Common options:

```text
-o, --output PATH   output path, or - for stdout
-f, --force         replace an existing output file
-h, --help          show help
    --version       show the package version
```

Compression also accepts `-l, --level 1..22`. Decompression accepts
`-m, --max-output-size BYTES`. Use `-` as the input to read stdin; it defaults
to stdout, so pipelines remain binary-clean. File compression appends `.zstd`.
File decompression strips `.zstd`, or appends `.out` when the input has no such
suffix. Existing outputs are refused unless `--force` is present; an output
that aliases the input is always refused.

Exit codes are 0 for success, 1 for I/O or codec failure, and 2 for invalid
arguments or a refused overwrite.

## Native library resolution

The package resolves the library through the active Dart package
configuration, independent of the process working directory.
`ZSTANDARD_CLI_LIBRARY` can name an explicit library for testing or custom
deployment; an executable-adjacent library is also supported for compiled
applications. Windows bundles use the static MSVC runtime and do not require a
matching redistributable solely for this library.

## Testing

```bash
dart test
dart analyze
```

Tests verify empty, unknown-size and concatenated frames, output bounds,
symbol exports, CWD-independent loading, file collisions, and CLI exit codes.

See the repository [CLI guide](https://github.com/vypdev/zstandard/blob/master/docs/platforms/cli.md)
for more detail.
