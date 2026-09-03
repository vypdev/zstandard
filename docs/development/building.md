# Building

For the current Apple dependency policy, see
[Apple Dependency Strategy](apple-dependencies.md).

This document describes how to build the Zstandard plugin, its native libraries, and the CLI package.

## All-in-one (macOS)

From the repository root, you can run sync, bindings, all macOS-runnable builds, and all tests in sequence:

```bash
./scripts/run_all_macos.sh
```

This runs: sync zstd (iOS + macOS) → regenerate bindings → build Android → build CLI (dylibs) → build iOS → build web → build macOS → test Android → test CLI → test iOS → test web → test macOS. Requires macOS, Flutter 3.44+, Xcode, CocoaPods (for compatibility-mode checks), Android SDK/NDK (for Android), and CMake. All platforms use the single canonical source at `zstandard_native/src/zstd/` (see workflow below). Stops on first failure.

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

All platforms use a **single source of truth** for the zstd C library: **`zstandard_native/src/zstd/`**. Android, Linux, and Windows compile directly from that path via CMake (`zstd_build/`). Swift Package Manager exposes the same path through the repository-level `Package.swift` for iOS and macOS. CocoaPods uses an ignored generated compatibility copy under each plugin’s `Classes/zstd/` (see below); those generated copies should not be edited.

If you are developing or modifying a platform package’s native code:

### Android

- The plugin builds the native library via `zstandard_android/zstd_build/CMakeLists.txt`, which compiles sources from `zstandard_native/src/zstd/` (resolved from the repo or pub cache).
- The Android plugin uses Built-in Kotlin with AGP 9 and newer. The Android examples exercise this path with Flutter 3.47+.
- Building the Android app (e.g. `flutter build apk` or running from Android Studio) triggers the native build via Gradle/CMake.
- Ensure the NDK is installed and that `zstandard_native` is available (e.g. `flutter pub get` so the canonical `zstandard_native/src/zstd/` is resolved).

### iOS / macOS

- The canonical source is **`zstandard_native/src/zstd/`**. Swift Package Manager consumes it through the repository-level `Package.swift`; the Apple plugin manifests link the shared `zstandard-native` product and do not carry a second C source tree.
- CocoaPods only sees files inside the pod, so each podspec uses a **`prepare_command`** (at pod install) and a **script phase** (before headers at build time) to copy that directory into `zstandard_ios/ios/Classes/zstd/` and `zstandard_macos/macos/Classes/zstd/` respectively. No `pre_install` in the app Podfile is required.
- The iOS and macOS generated copies are retained after the build and ignored by Git; this prevents cleanup phases from deleting files while Xcode is compiling them.
- To build with Swift Package Manager, use Flutter 3.44 or newer and enable it with `flutter config --enable-swift-package-manager`. To build with CocoaPods, use `flutter config --no-enable-swift-package-manager`, run `pod install`, and then build the example app.
- The checked-in Apple examples target iOS 15.0 and macOS 12.0, matching the minimum deployment targets enforced by the Flutter 3.47.2 SDK used in CI.
- In SwiftPM mode the native target is statically linked into the app and Dart FFI resolves its symbols from the process. In CocoaPods mode the plugin framework is embedded and loaded by path.

The Apple workflows run the example applications through a matrix covering both dependency managers (`swiftpm` and `cocoapods`) and both native-source locations (the repository workspace and the pub cache). Each workflow limits its native matrix to one job at a time, while runner availability determines whether the iOS and macOS workflows run concurrently. There is no cross-workflow concurrency group that could discard queued matrix jobs. Each native job builds the example, launches it through Flutter's integration-test runner, and executes the integration tests on the iOS simulator or macOS desktop. The runner uses its preinstalled Apple Silicon Flutter SDK; no SDK download action is used.

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

2. **Refresh the CocoaPods compatibility trees when needed**:
   ```bash
   bash zstandard_ios/scripts/sync_zstd.sh
   bash zstandard_macos/scripts/sync_zstd.sh
   ```
   These copy `zstandard_native/src/zstd/` into each plugin’s ignored `Classes/zstd/` tree. The **podspecs** also run the same scripts: `prepare_command` at pod install and a script phase before headers at build time. Swift Package Manager does not use these generated trees.

   The iOS and macOS podspecs keep their generated `Classes/zstd` directories after the build. Never commit or edit them.

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
- **Apple dependency errors**: For Swift Package Manager, run `flutter clean`, reset package caches in Xcode, and retry with Flutter 3.44+. For CocoaPods, run `flutter config --no-enable-swift-package-manager` followed by `pod install` in the example’s `ios/` or `macos/` directory.

See [Troubleshooting](../troubleshooting/common-issues.md) for more.
