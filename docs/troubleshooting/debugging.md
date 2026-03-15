# Debugging

Tips for debugging issues with the Zstandard plugin and CLI.

## Enable logging

The plugin may log errors or debug info. Check whether the implementation uses `dart:developer` log or `print` and enable verbose logging if available. On Flutter, you can use `debugPrint` in your app to trace input/output sizes and null returns.

## Verify input and output

- **Compress**: Log the length of the input and the compressed result. If the result is null, the implementation failed (check platform-specific logs).
- **Decompress**: Ensure the input is exactly the bytes that were produced by `compress` (same buffer, no truncation). Try decompressing in a minimal test (e.g. roundtrip in main).

## Minimal repro

- Isolate the issue: one platform, one call (e.g. `Zstandard().compress(data, 3)` with a small `Uint8List`). If it works in isolation, the problem may be with data source, size, or concurrency.
- Test with the **example** app in the repo. If the example works but your app doesn’t, compare dependencies, Flutter version, and how you call the API.
- For native crashes, get a minimal Dart snippet and the exact device/OS/architecture.

## Platform-specific debugging

- **Android**: Use `adb logcat` and filter by your app or “zstd”/“zstandard”. Look for `UnsatisfiedLinkError` or native stack traces.
- **iOS/macOS**: Use Xcode’s debugger and console. Check that the correct scheme and architecture are selected.
- **Linux/Windows**: Run from the terminal and check stderr. Use a debug build if needed (`flutter run -d linux` or `windows`).
- **Web**: Use the browser’s Developer Tools (Console, Network). Confirm `zstd.js` and `zstd.wasm` load (200 status). Step through or log in the JS if you suspect the wrapper.
- **CLI**: Run `dart test` in the zstandard_cli package. If tests pass, the library loads; then narrow down your usage (e.g. file path, data size).

## Analyzer and tests

- Run `flutter analyze` (or `dart analyze`) and fix all errors. Warnings may point to null or type issues that only show at runtime in some paths.
- Run unit tests: `flutter test` in the main and platform packages. Fix any failures; they often reveal API misuse or platform assumptions.

## Native build issues

- **CMake (Linux/Windows)**: Run CMake with verbose output to see which compiler and paths are used. Ensure the zstd source path in the plugin’s CMake is correct.
- **CocoaPods (iOS/macOS)**: Run `pod install` with `--verbose`. Check that the plugin’s podspec is found and that the native target is built.
- **Gradle (Android)**: Run `flutter build apk --verbose` and check the native build step; ensure NDK is installed and the ABI is correct.

## Reporting a bug

When opening an issue, include:

- Package and version (e.g. zstandard 1.3.29)
- Platform (Android, iOS, macOS, Windows, Linux, web, CLI)
- Flutter/Dart version
- Minimal code that reproduces the issue
- Expected vs actual behavior
- Any error messages or logs (full stack trace for crashes)
- For native issues: OS version and architecture (e.g. arm64, x64)

## See also

- [Common issues](common-issues.md)
- [Platform issues](platform-issues.md)
- [Testing](../development/testing.md)
