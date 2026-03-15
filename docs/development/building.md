# Building

This document describes how to build the Zstandard plugin, its native libraries, and the CLI package.

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

- The zstd source is typically under `ios/Classes/zstd/` (iOS) or `src/` (macOS).
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

## FFI Bindings Regeneration

If you change the zstd C API surface or headers used by the plugin:

1. Install **ffigen** (and LLVM if required): see the Dart FFI documentation.
2. Each platform package that uses FFI typically has an `ffigen` config (e.g. `ffigen.yaml` or in `pubspec.yaml`).
3. Run ffigen for that package (e.g. `dart run ffigen` from the package directory) to regenerate the `*_bindings_generated.dart` file.
4. Commit the updated bindings so that others and CI use the same bindings.

## Troubleshooting

- **Native library not found at runtime**: Ensure you built for the correct platform/architecture and that the library is in the path or next to the executable as the plugin expects.
- **CMake errors**: Install the required build tools (CMake, C compiler) and ensure the zstd source path in CMake matches the package layout.
- **CocoaPods errors**: Run `pod install` in the example’s `ios/` or `macos/` and ensure the plugin’s podspec is correct.

See [Troubleshooting](../troubleshooting/common-issues.md) for more.
