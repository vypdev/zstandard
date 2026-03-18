# Installation

This page covers platform-specific installation and setup for the Zstandard plugin and CLI.

## Flutter app (all platforms)

Add the main plugin to your app:

```yaml
dependencies:
  zstandard: ^1.4.0
```

Run:

```bash
flutter pub get
```

No extra steps are required for **Android, iOS, macOS, Windows, or Linux**; the federated plugin pulls in the right implementation and builds the native code when you build your app.

## Web

For **Flutter web**, you must add two assets and include a script:

1. Copy **zstd.js** and **zstd.wasm** from the [zstandard_web](https://github.com/vypdev/zstandard/tree/master/zstandard_web) package (e.g. from its `blob/` or as documented there) into your app’s **web/** directory (e.g. `web/zstd.js`, `web/zstd.wasm`).

2. In **web/index.html**, include the script before your app loads:

```html
<!DOCTYPE html>
<html>
<head>
  <script src="zstd.js"></script>
</head>
<body>
  <script src="main.dart.js" type="application/javascript"></script>
</body>
</html>
```

Without these, the web implementation will not work. See [Platforms — Web](../platforms/web.md) for details.

## CLI (Dart only)

For a **pure Dart** project (no Flutter) on macOS, Windows, or Linux:

```yaml
dependencies:
  zstandard_cli: ^1.4.0
```

```bash
dart pub get
```

The package ships with precompiled native libraries; no extra installation is needed. See [Platforms — CLI](../platforms/cli.md).

## Verifying installation

- **Flutter**: Run your app on the desired platform and call `Zstandard().compress(data, 3)` and `decompress(compressed)`; check that you get a non-null result for valid input.
- **Web**: Ensure no console errors about `compressData`/`decompressData` or WASM loading.
- **CLI**: Run `dart test` inside the `zstandard_cli` package or use `dart run zstandard_cli:compress` in a project that depends on it.

## See also

- [Getting started](getting-started.md)
- [Platforms](../platforms/) — Per-platform details
