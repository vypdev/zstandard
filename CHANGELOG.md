## Unreleased

- Added bounded decompression (256 MiB default) with support for unknown-size
  and concatenated frames across native, Web, CLI, and extension APIs.
- Moved native work to byte-safe isolates and WebAssembly work to a dedicated
  Web Worker; empty input now always produces a valid zstd frame.
- Reworked CLI argument parsing, stdin/stdout support, collision protection,
  library resolution, exported-symbol tests, and finite benchmark reporting.
- Pinned native provenance, dependency sources, Apple versions, Emscripten,
  third-party Actions, and aligned SwiftPM/CocoaPods native source sets.
- Split release preparation from immutable tag-triggered OIDC publishing and
  added a GitHub-hosted, read-only safety gate for untrusted pull requests and
  a separate reviewed release-integration workflow.
- Fixed intermittent iOS and macOS build failures caused by deleting synced zstd sources during compilation.
- Updated the minimum supported SDK version to Flutter 3.44/Dart 3.12 and migrated Android builds to Built-in Kotlin on AGP 9+.
- Removed obsolete Android Jetifier settings, stale workflow paths, and 58 MiB of unreferenced repository media.
- Removed placeholder `WIP` tests, isolated the legacy Android example's analysis,
  and migrated the CLI away from deprecated platform APIs.
- Added Swift Package Manager support for iOS and macOS while retaining CocoaPods compatibility.

## 1.5.0 - Dependencies Updated

- Updated direct dependencies
- Updated native bindings

## 1.4.4 - Apple C Script

- Fixed Apple compilation script resolution

## 1.4.3 - Apple C Script

- Fixed Apple compilation script resolution

## 1.4.2 - C Provider

- Added `zstandard_native` to provide C code to the rest of the plugins
- Increased test to consume C files (local and pub-cache resolution).

## 1.4.0 - Zstd Update

- Zstd lib updated
- Multiple symbol resolution bugs fixed
- Unified source of zstd (not one per platform)
- Web de/compression improved

## 1.3.32 - Test Release

- Test release

## 1.3.31 - Test Release

- Test release

## 1.3.30 - Test release

- Test release

## 1.3.29

* Test deploy

## 1.3.27

* Fixed decompression size.
* Added [CLI](https://pub.dev/packages/zstandard_cli) support.
* Added `compressionLevel` parameter.
* Github Actions.
* Doc updated

## 1.2.0

* Added Windows support.
* Added Linux support.
* Added extension functions.

## 1.1.1

* README.md updated.

## 1.1.0

* Added Android support.
* Added iOS support.
* Added macOS support.

## 1.0.0

* First version. `compress` and `decompress`.
* Added Web support.
