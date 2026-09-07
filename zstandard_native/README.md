# zstandard_native

Native zstd C sources and FFI bindings used by the [zstandard](https://pub.dev/packages/zstandard) Flutter plugin platform implementations (Android, iOS, macOS, Linux, Windows) and CLI.

## Contents

- **`src/zstd/`** — C source code from [facebook/zstd](https://github.com/facebook/zstd) (common, compress, decompress).
- **`lib/zstandard_native_bindings.dart`** — FFI bindings generated from `zstd.h` for use by all platform plugins.
- **`lib/src/zstandard_native_codec.dart`** — Shared bounded byte-oriented codec used by every native implementation.
- **`UPSTREAM_ZSTD.md`** — Exact upstream version, commit, and locally applied upstream backport.

## Usage

This package is a dependency of the platform-specific zstandard plugins. End users depend on `zstandard` (or individual platform packages); they do not need to depend on `zstandard_native` directly.

### Development (monorepo)

From the repository root, run `scripts/create_local_overrides.sh <package>` to
resolve the monorepo packages by path for local tests. Generated
`pubspec_overrides.yaml` files are ignored and must not be published. During a
release, publish `zstandard_native` after the platform interface and before
the platform packages and CLI.

### Regenerating bindings

From this package directory:

```bash
dart run ffigen --config ffigen.yaml
```

Or from the repo root:

```bash
./scripts/regenerate_bindings.sh
```

## Updating zstd sources

From the repository root:

```bash
./scripts/update_zstd.sh
```

This refreshes `zstandard_native/src/zstd/` from the exact requested upstream
revision (the repository default is pinned). Update `UPSTREAM_ZSTD.md` whenever
the revision or the recorded backport changes.
