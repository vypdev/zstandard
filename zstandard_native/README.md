# zstandard_native

Native zstd C sources and FFI bindings used by the [zstandard](https://pub.dev/packages/zstandard) Flutter plugin platform implementations (Android, iOS, macOS, Linux, Windows) and CLI.

## Contents

- **`src/zstd/`** — C source code from [facebook/zstd](https://github.com/facebook/zstd) (common, compress, decompress).
- **`lib/zstandard_native_bindings.dart`** — FFI bindings generated from `zstd.h` for use by all platform plugins.

## Usage

This package is a dependency of the platform-specific zstandard plugins. End users depend on `zstandard` (or individual platform packages); they do not need to depend on `zstandard_native` directly.

### Development (monorepo)

From the repository root, the main **example** app uses `dependency_overrides` in `zstandard/example/pubspec.yaml` so that all packages (including `zstandard_native`) resolve from path. Run `flutter pub get` and builds from the example. When publishing to pub.dev, publish **zstandard_native** first, then the platform packages and the main plugin (they depend on `zstandard_native: ^1.4.0`).

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

This updates `zstandard_native/src/zstd/` from the official facebook/zstd repository.
