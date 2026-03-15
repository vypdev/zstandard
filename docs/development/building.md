# Building

This document describes how to build the Zstandard plugin, its native libraries, and the CLI package.

## All-in-one (macOS)

From the repository root, you can run sync, bindings, all macOS-runnable builds, and all tests in sequence:

```bash
./scripts/run_all_macos.sh
```

This runs: sync zstd (from repo root `zstd/`) → regenerate bindings → build Android → build CLI (dylibs) → build iOS → build web → build macOS → test Android → test CLI → test iOS → test web → test macOS. Requires macOS, Flutter, Xcode, CocoaPods, Android SDK/NDK (for Android), and CMake. Ensure the canonical source exists at `zstd/` (see step 1 below). Stops on first failure.

## Flutter Plugin (All Platforms)

### Build the example app

From the repository root:

```bash
cd zstandard/example
flutter pub get
flutter run
```

Select the target platform (Android, iOS, macOS, Windows, Linux, web). This will compile the plugin and, for native platforms, the platform-specific native code as part of the Flutter build.

### Build release artifacts

```bash
cd zstandard/example
flutter build apk          # Android
flutter build ios           # iOS
flutter build macos         # macOS
flutter build windows       # Windows
flutter build linux         # Linux
flutter build web           # Web
```

The native libraries (e.g. Android .so, iOS framework, Windows DLL, Linux .so) are built automatically by Flutter’s build system when you build the app that uses the plugin.

## Native Libraries (Platform Packages)

If you are developing or modifying a platform package’s native code:

### Android

- The native zstd code is under the platform package’s `android/` and/or `src/` (or as specified in the package).
- Building the Android app (e.g. `flutter build apk` or running from Android Studio) triggers the native build via Gradle/CMake.
- Ensure the NDK is installed and that `android/app/build.gradle` (or the plugin’s build config) is set up to compile the native library.

### iOS / macOS

- The zstd source is under `ios/Classes/zstd/` (iOS) and `macos/Classes/zstd/` (macOS); both are copies from the canonical source at repo root **`zstd/`**.
- To update the zstd code in **both** iOS and macOS from that canonical source, run from the repo root:
  ```bash
  ./scripts/sync_zstd_ios_macos.sh
  ```
- Build the example app for iOS or macOS; Xcode/CocoaPods will build the native target.
- For macOS, the product may be a framework or dylib that the Dart code loads by name.

### Linux

- Native code is under the package’s `src/`; the build is usually under `linux/` using CMake.
- From the example app: `flutter build linux` or `flutter run -d linux` will invoke CMake and produce `libzstandard_linux_plugin.so` (or the configured name).
- You can also run CMake manually from the package’s `linux/` directory if the project documents it.

### Windows

- Native code is under the package’s `src/`; the build is usually under `windows/` using CMake.
- From the example app: `flutter build windows` or `flutter run -d windows` will invoke CMake and produce the plugin DLL.
- You can run CMake manually from the package’s `windows/` directory if needed.

### Web

- No native “build” in the C sense. You need `zstd.js` and `zstd.wasm` in the app’s `web/` directory.
- To regenerate them: use Emscripten to compile the facebook/zstd C library and add the `compressData`/`decompressData` wrappers. See [Web Implementation](../architecture/web-implementation.md) and the zstandard_web README.

## CLI Package

The CLI is pure Dart plus FFI; it uses **precompiled** native libraries shipped with the package (macOS, Windows, Linux).

### Run tests

```bash
cd zstandard_cli
dart test
```

### Run the CLI entry points

```bash
dart run zstandard_cli:compress <file> <level>
dart run zstandard_cli:decompress <file.zstd>
```

### Building a standalone executable (optional)

```bash
cd zstandard_cli
dart compile exe bin/compress.dart   # if the package exposes such a script
# or use the package’s documented entry point
```

The compiled executable will still need the native library (e.g. .dylib, .dll, .so) to be available at runtime as the package expects.

## Workflow: updating zstd and running the app (do not edit native zstd)

**Do not modify the native zstd C library by hand.** The flow is:

1. **Update the canonical zstd source**  
   The source of truth is **`zstd/`** at the repo root. Update it only by replacing it with an upstream release (e.g. from [facebook/zstd](https://github.com/facebook/zstd)); do not edit the C files manually.  
   If `zstd/` or the iOS/macOS `Classes/zstd/` trees are missing (e.g. after a clean clone), copy the contents of the upstream `lib/` directory into `zstd/` (e.g. `git clone --depth 1 https://github.com/facebook/zstd.git /tmp/zstd && mkdir -p zstd && cp -R /tmp/zstd/lib/* zstd/`). If you previously had the canonical source at `zstandard_macos/src/`, move it once: `mv zstandard_macos/src zstd`.

2. **Sync zstd to iOS and macOS** (from repo root):
   ```bash
   ./scripts/sync_zstd_ios_macos.sh
   ```
   This copies `zstd/` to `zstandard_ios/ios/Classes/zstd/` and `zstandard_macos/macos/Classes/zstd/`, and removes `module.modulemap` on both so the pods build correctly (legacy and module conflicts).

3. **Regenerate FFI bindings** (from repo root):
   ```bash
   ./scripts/regenerate_bindings.sh
   ```
   This runs `dart run ffigen` in each platform package (android, ios, macos, linux, windows, cli). Commit any changed `*_bindings_generated.dart` files.

4. **Run the app** (e.g. `flutter run` from `zstandard/example` for the desired platform).

Android, Linux, and Windows each have their own `src/` tree; they are not synced from the iOS/macOS script. If you update zstd for those platforms, update their `src/` accordingly (again, without editing the C code by hand), then run the bindings script.

## FFI Bindings Regeneration (manual)

If you only need to regenerate bindings for one package:

1. Install **ffigen** (and LLVM if required): see the Dart FFI documentation.
2. From the package directory (e.g. `zstandard_ios`), run: `dart run ffigen --config ffigen.yaml`.
3. Commit the updated `*_bindings_generated.dart` file.

## Troubleshooting

- **Native library not found at runtime**: Ensure you built for the correct platform/architecture and that the library is in the path or next to the executable as the plugin expects.
- **CMake errors**: Install the required build tools (CMake, C compiler) and ensure the zstd source path in CMake matches the package layout.
- **CocoaPods errors**: Run `pod install` in the example’s `ios/` or `macos/` and ensure the plugin’s podspec is correct.

See [Troubleshooting](../troubleshooting/common-issues.md) for more.
