# Glossary

Definitions of terms and acronyms used in the Zstandard plugin and CLI documentation.

**API** — Application Programming Interface. The public methods and types exposed by the plugin (e.g. `Zstandard().compress()`, `decompress()`).

**ARM64** — 64-bit ARM architecture. Used by Apple Silicon (M1/M2/M3), many Android devices, and some Windows/Linux machines.

**CLI** — Command-Line Interface. The `zstandard_cli` package provides both an in-code API and command-line tools (`dart run zstandard_cli:compress`, `decompress`).

**Compression level** — Integer from 1 to 22 controlling the trade-off between speed and compression ratio. Level 1 is fastest; level 22 gives the smallest output.

**Dart** — The programming language used for the plugin and CLI. See [dart.dev](https://dart.dev).

**Decompress** — Convert Zstandard-compressed bytes back to the original uncompressed data.

**FFI** — Foreign Function Interface. The mechanism in Dart that allows calling native (C/C++) code. The plugin uses FFI to call the zstd C library on Android, iOS, macOS, Windows, and Linux.

**Flutter** — The UI toolkit and framework. The main **zstandard** package is a Flutter plugin; **zstandard_cli** is pure Dart (no Flutter).

**Federated plugin** — A Flutter plugin that delegates to platform-specific implementations (e.g. zstandard_android, zstandard_ios) rather than implementing everything in one package. The **zstandard_native** package holds the shared C source (facebook/zstd) used by all native implementations and the CLI; it is published to pub.dev as part of the release set.

**Frame** — A Zstandard-compressed unit of data with a header and optional checksum. The API compresses and decompresses one frame at a time (or a single buffer that may contain a frame).

**Isolate** — A Dart concurrency unit. The native implementations may run compression/decompression in a separate isolate so the UI thread is not blocked.

**LCOV** — A format for code coverage data. `flutter test --coverage` and the coverage package produce LCOV (e.g. `lcov.info`) for tools like Codecov.

**Native** — Code that runs on the host OS (C/C++, Kotlin, Swift, etc.) as opposed to Dart or JavaScript. The zstd library is native; the plugin wraps it via FFI.

**Precompiled** — Built in advance (e.g. the CLI’s native libraries for macOS, Windows, Linux are precompiled and shipped with the package).

**pub.dev** — The default package repository for Dart and Flutter. Packages are published there with `dart pub publish`.

**Uint8List** — A Dart type for a list of unsigned 8-bit bytes. The plugin’s compress and decompress APIs use `Uint8List` for input and output.

**WASM / WebAssembly** — A binary format for running code in browsers. The **zstandard_web** implementation compiles zstd to WASM and loads it via JavaScript.

**x64 / x86_64** — 64-bit Intel/AMD architecture. Supported on macOS, Windows, Linux, and Android emulators.

**zstd** — Zstandard. The compression algorithm and library developed by Meta (Facebook). The plugin and CLI wrap the official [facebook/zstd](https://github.com/facebook/zstd) C library.

**Zstandard** — Same as zstd; the full name of the algorithm and format.
