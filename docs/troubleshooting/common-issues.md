# Common Issues

Frequently encountered issues and how to resolve them.

## compress or decompress returns null

**Cause**: Compression or decompression failed. For decompress, the input is often not valid Zstandard data (corrupted, truncated, or never compressed with zstd).

**What to do**:
- Check that the input is non-null and, for decompress, that it is a complete zstd frame.
- If decompressing data from a file or network, verify the source (e.g. file not truncated, correct format).
- Log or handle the null in your code; see [Error handling](../guides/error-handling.md).

## Extension on null returns null

**Cause**: The extension is on `Uint8List?`. When the receiver is null, `compress()` and `decompress()` return null by design.

**What to do**: Use null-aware code: `final c = await maybeData?.compress();` and check `c != null` before use.

## Web: "compressData is not defined" or similar

**Cause**: The web implementation requires `zstd.js` (and `zstd.wasm`) to be loaded before the app runs. The script was not included or failed to load.

**What to do**:
- Add `<script src="zstd.js"></script>` in `web/index.html` (before your app script).
- Ensure `zstd.js` and `zstd.wasm` are in your `web/` directory and that the paths are correct.
- Open the browser console and fix any script load errors (e.g. 404, CORS). See [Platforms — Web](../platforms/web.md).

## Native library not found (Android, iOS, macOS, Linux, Windows)

**Cause**: The plugin’s native library (e.g. .so, .dylib, .dll) was not built or is not in the path the plugin expects.

**What to do**:
- Build the app for the target platform (e.g. `flutter build apk`, `flutter run -d linux`). Do not assume copying a prebuilt binary is enough unless the plugin documents it.
- Ensure you are on a supported architecture (e.g. arm64, x64). Simulator/emulator architecture must match (e.g. iOS simulator x86_64/arm64).
- On Linux, set `LD_LIBRARY_PATH` if the .so is not next to the executable. On Windows, ensure the DLL is in the same directory as the executable or in PATH.

## CLI: Library load error on desktop

**Cause**: zstandard_cli uses precompiled native libraries. The library for your platform/architecture may be missing or incompatible.

**What to do**:
- Run on a supported platform: macOS, Windows, or Linux, and x64 or arm64.
- Update the package: `dart pub upgrade zstandard_cli`.
- If the problem persists, open an issue with your OS and architecture (e.g. `uname -m`, Windows version).

## Slow compression on large data

**Cause**: Higher compression levels and larger inputs take more CPU time.

**What to do**:
- Use a lower level (e.g. 1–3) for speed; see [Compression levels](../guides/compression-levels.md).
- On native platforms, the plugin should use a background isolate; ensure you are not blocking the main isolate elsewhere.
- Consider chunking very large data to limit peak memory and to show progress.

## Version mismatch or dependency resolution errors

**Cause**: Different packages in the repo (or your app) depend on different versions of zstandard or platform packages.

**What to do**:
- Use a consistent version in your `pubspec.yaml` (e.g. `zstandard: ^1.3.29`). Run `flutter pub get` and check for resolution errors.
- If you depend on multiple packages from this repo, align their versions (e.g. all ^1.3.29). See [Migration guide](../guides/migration-guide.md).

## See also

- [Platform issues](platform-issues.md)
- [Debugging](debugging.md)
- [Error handling](../guides/error-handling.md)
