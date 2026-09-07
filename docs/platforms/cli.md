# CLI Platform Guide

`zstandard_cli` is a pure-Dart API and command-line package for macOS, Windows,
and Linux. Bundled native libraries support x64 and arm64.

## Installation and API

```yaml
dependencies:
  zstandard_cli: ^1.5.0
```

```dart
final codec = ZstandardCLI();
final compressed = await codec.compress(data, compressionLevel: 3);
final decompressed = compressed == null
    ? null
    : await codec.decompress(
        compressed,
        maxOutputSize: 16 * 1024 * 1024,
      );
```

Empty input produces a valid frame. Streaming decompression supports frames
without a declared size and concatenated frames, with a 256 MiB default output
budget.

## Commands

```bash
dart run zstandard_cli:compress --level 5 input.bin
dart run zstandard_cli:decompress --max-output-size 16777216 input.bin.zstd
```

Use `--output PATH` to select output and `--force` to replace an existing
file. Input `-` reads stdin and defaults to stdout, enabling binary pipelines.
Run either command with `--help` for its exact options and naming rules.

The commands return 0 on success, 1 on I/O/codec failure, and 2 on invalid
usage or unsafe overwrite. An output that aliases the input is always refused.

## Native loading and deployment

The loader selects a packaged library using the package URI, not the current
working directory. It also supports compiled-executable adjacency and an
explicit `ZSTANDARD_CLI_LIBRARY` override. Windows CLI binaries link the MSVC
runtime statically to avoid an otherwise undeclared redistributable dependency.

Public API operations pass bytes to the shared native codec and never expose
FFI allocation ownership. Callers doing concurrent large operations should
still cap their own concurrency and output budgets.

## Testing

Run `dart test` and `dart analyze` on each target OS. The test suite verifies
the bundled symbol surface and the native roundtrip in addition to argument,
file-safety, and loading behavior.

See [CLI API](../api/cli-api.md) and [FFI architecture](../architecture/ffi-implementation.md).
