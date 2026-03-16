# Platform-Specific Issues

Issues that are specific to one platform or environment.

## Android

- **UnsatisfiedLinkError / native library not found**: Build the app with `flutter build apk` or run from Android Studio so the plugin’s .so is built and packaged. Ensure the ABI (arm64-v8a, armeabi-v7a, x86_64) matches your device or emulator.
- **Crashes in compress/decompress**: Ensure you are not passing null where `Uint8List` is required and that the data is not corrupted (for decompress). Check logcat for native crashes.

## iOS

- **Symbol not found / dylib load**: Ensure the iOS target is built (e.g. run from Xcode or `flutter run -d ios`) and that you are targeting a supported architecture (arm64 device, x86_64/arm64 simulator).
- **CocoaPods issues**: Run `pod install` in the example’s `ios/` directory. Clear DerivedData if the plugin’s native code still doesn’t link.

## macOS

- **Library not loaded**: The plugin loads a dynamic library (e.g. .dylib or framework). Ensure the app is built with `flutter build macos` or run from Xcode. For Apple Silicon vs x64, use the correct build target.

## Windows

- **DLL not found**: The plugin expects its DLL (e.g. `zstandard_windows_plugin.dll`) to be loadable. Build with `flutter build windows`; the DLL should be next to the executable. If you deploy manually, copy the DLL as well.
- **Wrong architecture**: Build for the correct architecture (x64 or arm64). Mixing 32-bit and 64-bit can cause load failures.

## Linux

- **libzstandard_linux_plugin.so not found**: Build with `flutter build linux` or run with `flutter run -d linux`. The .so is produced by CMake. If you run the binary from another directory, set `LD_LIBRARY_PATH` to the directory containing the .so or place the .so next to the executable.

## Web

- **WASM or JS errors**: Ensure `zstd.js` and `zstd.wasm` are served from the same origin (or CORS is set correctly) and that the path in the script matches. Check the browser console and network tab.
- **compressData/decompressData undefined**: The script must load before the Flutter app. Put `<script src="zstd.js"></script>` in `<head>` and ensure it loads without errors.
- **Slow or blocking**: Web runs on the main thread. For large data, consider chunking or offloading to a Web Worker if you implement it.

## CLI (macOS, Windows, Linux)

- **Only desktop**: The CLI package does not run on mobile or web. Use the main Flutter plugin for those.
- **Library load failure**: Ensure you are on a supported OS and architecture (x64 or arm64). Update the package; if the problem persists, report the OS and arch.

## See also

- [Common issues](common-issues.md)
- [Debugging](debugging.md)
- [Platforms](../platforms/) — Per-platform setup
