# Development Setup

This guide describes how to set up your machine to develop and contribute to the Zstandard plugin and CLI.

## Prerequisites

- **Dart SDK**: ^3.6.0 (see each package’s `pubspec.yaml` for the exact constraint).
- **Flutter SDK**: >=3.3.0 (for plugin and example apps).
- **Git**: To clone and work with the repository.

Optional, for native work:

- **Android**: Android Studio / SDK and NDK if you modify Android native code.
- **iOS/macOS**: Xcode and CocoaPods if you modify iOS/macOS native code.
- **Linux**: CMake and a C compiler (gcc/clang) for building the Linux plugin.
- **Windows**: CMake and Visual Studio Build Tools (or equivalent) for building the Windows plugin.
- **Web**: Node/npm optional; Emscripten is needed only if you rebuild zstd.js/zstd.wasm.

## Clone the Repository

```bash
git clone https://github.com/vypdev/zstandard.git
cd zstandard
```

If you use a fork:

```bash
git remote add upstream https://github.com/vypdev/zstandard.git
```

## Get Dependencies

From the repository root, fetch dependencies for all packages:

```bash
flutter pub get
```

Then, for each package you will work on:

```bash
cd zstandard
flutter pub get

cd ../zstandard_platform_interface
flutter pub get

cd ../zstandard_android   # or ios, macos, linux, windows, web
flutter pub get

cd ../zstandard_cli
dart pub get
```

Or use a script if the project provides one to run `pub get` in all packages.

## IDE Setup

- **VS Code / Cursor**: Install the Dart and Flutter extensions. Open the repo root so that all packages are visible.
- **Android Studio / IntelliJ**: Install the Flutter plugin and open the repo root. Ensure the Dart SDK is configured.

## Verifying the Setup

1. **Analyze**: From the repo root, run:
   ```bash
   flutter analyze
   ```
   Fix any reported issues in the packages you touch.

2. **Tests**: Run tests for the main package and the one you are changing:
   ```bash
   cd zstandard && flutter test
   cd ../zstandard_cli && dart test
   ```
   See [Testing](testing.md) for full test commands.

3. **Example app**: Run the example app for your target platform to confirm the plugin works:
   ```bash
   cd zstandard/example
   flutter run
   ```
   Choose the desired platform (e.g. Android, iOS, macOS, Windows, Linux, web).

## Platform-Specific Notes

- **Android**: Ensure `ANDROID_HOME` is set and that an emulator or device is available.
- **iOS/macOS**: Ensure Xcode and CocoaPods are installed. Run `pod install` in the example’s `ios/` or `macos/` if needed.
- **Linux**: Install CMake and the build essentials; the Linux plugin’s CMake will build the native library.
- **Windows**: Ensure CMake and a C++ toolchain are available; the Windows plugin’s CMake will build the DLL.
- **Web**: No native build required for running the app; ensure `zstd.js` and `zstd.wasm` are in the example’s `web/` if you run the web example.

## Next Steps

- [Building](building.md) — How to build the plugin and native code.
- [Testing](testing.md) — How to run and write tests.
- [Code Style](code-style.md) — Coding standards.
