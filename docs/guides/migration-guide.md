# Migration Guide

This page helps you upgrade between versions of the Zstandard plugin and CLI with minimal breakage.

## General approach

1. **Check the CHANGELOG** for the version you are upgrading to. Look for "Breaking changes" or "Deprecation".
2. **Update dependencies** in `pubspec.yaml` to the new version (e.g. `zstandard: ^1.3.30`).
3. **Run** `flutter pub get` (or `dart pub get` for CLI).
4. **Fix analyzer and tests**: run `flutter analyze` and `flutter test` (or `dart test`) and address any new errors or deprecations.
5. **Manually test** compress/decompress and platform-specific paths (e.g. web, Android) that you use.

## Dependency version constraints

- Prefer **caret** constraints for compatibility with patch updates: `zstandard: ^1.3.29`.
- If you must pin exact versions, use `zstandard: 1.3.29`. Prefer caret for easier upgrades.

## API stability

- The main plugin API (`Zstandard()`, `compress`, `decompress`, extensions on `Uint8List?`) is stable. New parameters are usually optional.
- The platform interface (`ZstandardPlatform`) is for implementors; application code should not depend on it directly. If you mock it in tests, check the CHANGELOG for any interface changes.

## Platform interface changes

If `ZstandardPlatform` gains new methods in a minor version, platform packages will implement them. As an app author you don’t need to change anything unless you implement or mock the platform yourself.

## Web assets

- If the web implementation’s required assets (zstd.js, zstd.wasm) or paths change, the CHANGELOG or zstandard_web README will note it. Update your `web/` copy and `index.html` script tag if needed.

## CLI

- CLI API (`ZstandardCLI`, extensions) is stable. Entry point names (e.g. `zstandard_cli:compress`) may be documented in the package README; check if they change.
- Precompiled native libraries are shipped with the package; no migration step unless you use custom builds.

## Reporting issues

If an upgrade breaks your app and the CHANGELOG doesn’t document it, open an issue with your previous version, new version, and a minimal repro.
