# Building

This document describes how to build the Zstandard plugin, its native libraries, and the CLI package.

## All-in-one (macOS)

From the repository root, you can run sync, bindings, all macOS-runnable builds, and all tests in sequence:

```bash
./scripts/run_all_macos.sh
```

This runs: sync zstd (iOS + macOS) → regenerate bindings → build Android → build CLI (dylibs) → build iOS → build web → build macOS → test Android → test CLI → test iOS → test web → test macOS. Requires macOS, Flutter, Xcode, CocoaPods, Android SDK/NDK (for Android), and CMake. All platforms use the single canonical source at `zstandard_native/src/zstd/` (see workflow below). Stops on first failure.

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

All platforms use a **single source of truth** for the zstd C library: **`zstandard_native/src/zstd/`**. Android, Linux, and Windows compile directly from that path via CMake (`zstd_build/`). iOS and macOS copy it into the plugin’s `Classes/zstd/` at pod install or build time (see below); that copy is temporary and should not be edited.

If you are developing or modifying a platform package’s native code:

### Android

- The plugin builds the native library via `zstandard_android/zstd_build/CMakeLists.txt`, which compiles sources from `zstandard_native/src/zstd/` (resolved from the repo or pub cache).
- Building the Android app (e.g. `flutter build apk` or running from Android Studio) triggers the native build via Gradle/CMake.
- Ensure the NDK is installed and that `zstandard_native` is available (e.g. `flutter pub get` so the canonical `zstandard_native/src/zstd/` is resolved).

### iOS / macOS

- The canonical source is **`zstandard_native/src/zstd/`**. CocoaPods only sees files inside the pod, so each podspec uses a **`prepare_command`** (at pod install) and a **script phase** (before headers at build time) to copy that directory into `zstandard_ios/ios/Classes/zstd/` and `zstandard_macos/macos/Classes/zstd/` respectively. No `pre_install` in the app Podfile is required.
- Ensure `zstandard_native/src/zstd/` is present (e.g. run `./scripts/update_zstd.sh` if needed, then `./scripts/sync_zstd_ios_macos.sh`). Then build the example app for iOS or macOS; the podspec sync and Xcode/CocoaPods will build the native target.
- The product is a framework that the Dart code loads via FFI.

### Linux

- The plugin builds the zstd library via `zstandard_linux/zstd_build/CMakeLists.txt`, which compiles sources from `zstandard_native/src/zstd/` (resolved from the repo or pub cache), and links it into the plugin.
- From the example app: `flutter build linux` or `flutter run -d linux` will invoke CMake and produce `libzstandard_linux_plugin.so`.

### Windows

- The plugin builds the zstd DLL via `zstandard_windows/zstd_build/CMakeLists.txt`, which compiles sources from `zstandard_native/src/zstd/` (resolved from the repo or pub cache).
- From the example app: `flutter build windows` or `flutter run -d windows` will invoke CMake and produce the plugin DLL and the bundled `zstandard_windows.dll`.

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

**Do not modify the native zstd C library by hand.** All platforms use the single **`zstandard_native/src/zstd/`** directory. The flow is:

1. **Update the canonical zstd source**  
   From repo root:
   ```bash
   ./scripts/update_zstd.sh        # latest from dev (upstream default)
   ./scripts/update_zstd.sh v1.5.6 # specific tag or branch
   ```
   This fetches from the [official repo](https://github.com/facebook/zstd) and updates `zstandard_native/src/zstd/`.

2. **Sync zstd into iOS and macOS** (so CocoaPods can see the C sources):
   ```bash
   ./scripts/sync_zstd_ios_macos.sh
   ```
   This copies `zstandard_native/src/zstd/` to `zstandard_ios/ios/Classes/zstd/` and `zstandard_macos/macos/Classes/zstd/`. The **podspecs** handle the sync automatically: `prepare_command` runs at pod install when applicable, and a script phase runs before headers at build time. You only need to run the script by hand in special cases (e.g. fresh clone before the first `pod install`, or right after `update_zstd.sh` if you want the copy in place before building).

   After each build, the iOS and macOS podspecs run a script phase that **removes** the copied `Classes/zstd` directory. The next build recreates it via the podspec’s sync phase.

3. **Regenerate FFI bindings** (from repo root):
   ```bash
   ./scripts/regenerate_bindings.sh
   ```
   This runs `dart run ffigen` in each platform package (android, ios, macos, linux, windows, cli). Commit any changed `*_bindings_generated.dart` files.

4. **Run the app** (e.g. `flutter run` from `zstandard/example` for the desired platform).

Because all platforms reference the same `zstandard_native/src/zstd/` directory, a single `update_zstd.sh` updates every platform at once.

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
