# Zstandard Example

This example demonstrates how to use the [zstandard](https://pub.dev/packages/zstandard) Flutter plugin for compression and decompression on all supported platforms.

## What it demonstrates

- **Compression**: Compress raw bytes using the Zstandard algorithm with a configurable compression level (1–22).
- **Decompression**: Decompress previously compressed data back to the original bytes.
- **Extension methods**: Use `Uint8List?.compress()` and `Uint8List?.decompress()` for a concise API.
- **Platform detection**: The plugin automatically uses the correct implementation (Android, iOS, macOS, Windows, Linux, or web) based on the current platform.

## Running the example

From this directory (`zstandard/example`):

```bash
flutter pub get
flutter run
```

Then select your target platform (e.g. Android, iOS, macOS, Windows, Linux, or Chrome for web).

For web, ensure `zstd.js` and `zstd.wasm` are in the app’s `web/` directory and that `web/index.html` includes `<script src="zstd.js"></script>`. See the [web platform guide](../../docs/platforms/web.md) for details.

## Integration tests

To run integration tests (requires a device or emulator for the target platform):

```bash
flutter test integration_test/
```

## Documentation

- [Getting started](../../docs/guides/getting-started.md)
- [API reference](../../docs/api/main-api.md)
- [Platform guides](../../docs/platforms/)
- [Troubleshooting](../../docs/troubleshooting/common-issues.md)

## Resources

- [Flutter documentation](https://docs.flutter.dev/)
- [Zstandard (zstd) algorithm](https://github.com/facebook/zstd)
