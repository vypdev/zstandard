## Unreleased

- Updated the minimum supported SDK version to Flutter 3.44/Dart 3.12.
- Migrated Android builds to Built-in Kotlin on AGP 9+.
- Removed legacy Kotlin task configuration so the consuming app owns Kotlin
  compiler settings.
- Added an AGP 8.11.1/Gradle 8.14 legacy example alongside the AGP 9.1.0
  example.
- Test debug and release APKs for armeabi-v7a, arm64-v8a, and x86_64, and run
  both Dart integration and native JNI instrumentation round-trip tests in CI.

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
