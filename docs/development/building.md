# Building

This document describes how to build the Zstandard plugin, its native libraries, and the CLI package.

## All-in-one (macOS)

From the repository root, you can run sync, bindings, all macOS-runnable builds, and all tests in sequence:

```bash
./scripts/run_all_macos.sh
```

This runs: verify zstd at repo root → regenerate bindings → build Android → build CLI (dylibs) → build iOS → build web → build macOS → test Android → test CLI → test iOS → test web → test macOS. Requires macOS, Flutter, Xcode, CocoaPods, Android SDK/NDK (for Android), and CMake. All platforms use the single canonical source at `zstd/` (see workflow below). Stops on first failure.

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

All platforms use a **single source of truth** for the zstd C library: **`zstd/`** at the repository root. Each platform references this directory (via `zstd_build/` CMake wrappers or podspec paths). There are no per-platform copies of the zstd source.

If you are developing or modifying a platform package’s native code:

### Android

- The plugin builds the native library via `zstandard_android/zstd_build/CMakeLists.txt`, which compiles sources from `../../zstd/`.
- Building the Android app (e.g. `flutter build apk` or running from Android Studio) triggers the native build via Gradle/CMake.
- Ensure the NDK is installed and that the canonical `zstd/` directory exists at repo root.

### iOS / macOS

- The podspecs reference the canonical **`zstd/`** at repo root directly (`../../zstd/` from the pod directory).
- Run `./scripts/sync_zstd_ios_macos.sh` to verify that `zstd/` exists (no copy is performed).
- Build the example app for iOS or macOS; Xcode/CocoaPods will build the native target.
- For macOS, the product may be a framework or dylib that the Dart code loads by name.

### Linux

- The plugin builds the zstd library via `zstandard_linux/zstd_build/CMakeLists.txt`, which compiles sources from `../../zstd/`, and links it into the plugin.
- From the example app: `flutter build linux` or `flutter run -d linux` will invoke CMake and produce `libzstandard_linux_plugin.so`.

### Windows

- The plugin builds the zstd DLL via `zstandard_windows/zstd_build/CMakeLists.txt`, which compiles sources from `../../zstd/`.
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

**Do not modify the native zstd C library by hand.** All platforms use the single **`zstd/`** directory at the repo root. The flow is:

1. **Update the canonical zstd source**  
   From repo root:
   ```bash
   ./scripts/update_zstd.sh        # latest from dev (upstream default)
   ./scripts/update_zstd.sh v1.5.6 # specific tag or branch
   ```
   This fetches from the [official repo](https://github.com/facebook/zstd) and updates `zstd/`. If you prefer to do it manually: `git clone --depth 1 https://github.com/facebook/zstd.git /tmp/zstd && mkdir -p zstd && cp -R /tmp/zstd/lib/* zstd/`.

2. **Sync zstd into iOS and macOS** (so CocoaPods can see the C sources):
   ```bash
   ./scripts/sync_zstd_ios_macos.sh
   ```
   This copies `zstd/` to `zstandard_ios/ios/Classes/zstd/` and `zstandard_macos/macos/Classes/zstd/`. If you build the **example app** (`zstandard/example`), the Podfile runs this script automatically in a `pre_install` hook, so you don't need to run it by hand. For other apps that depend on the plugin, run the script once after updating zstd, or add the same `pre_install` snippet to your app's Podfile (see the example app's `ios/Podfile` and `macos/Podfile`).

After each build, the iOS and macOS podspecs run a script phase that **removes** the copied `Classes/zstd` directory, so the copy is only present during the build. The next build runs `pod install` again (and thus `pre_install` → sync), so the copy is recreated automatically.

3. **Regenerate FFI bindings** (from repo root):
   ```bash
   ./scripts/regenerate_bindings.sh
   ```
   This runs `dart run ffigen` in each platform package (android, ios, macos, linux, windows, cli). Commit any changed `*_bindings_generated.dart` files.

4. **Run the app** (e.g. `flutter run` from `zstandard/example` for the desired platform).

Because all platforms reference the same `zstd/` directory, a single `update_zstd.sh` updates every platform at once.

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
