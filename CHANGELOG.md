## 1.5.3 - Repair nested SDK setup before pub.dev publication

- Fix nested publication SDK setup by disabling its optional analyzer problem matcher. Preserve fresh OIDC credentials for every package and all publication dry runs.
- Add regression coverage for an inherited composite action path with no matcher asset, including failure before any package upload.
- Retain the accepted publisher, checkout, Apple host cleanup and Android emulator-session fixes from production 1.5.2; regenerate all distributable outputs during deployment preparation.
- Document recovery from a tagged workflow that failed before its first package upload.
- Minimum SDKs remain Dart ^3.12.0 and Flutter >=3.44.0; validation uses Flutter 3.47.2.

## 1.5.2 - Release recover package publication safely

- Fix package publication so Flutter resolves only the distributable package, without resolving example apps that mix local and hosted dependencies.
- Renew pub.dev OIDC credentials for each package after the previous package has finished indexing.
- Retain all release-preparation fixes and generated artifacts accepted in production by PR #169; regenerate every distributable artifact in the new deployment preparation phase.
- Document recovery from a partial immutable publication.
- Minimum supported SDKs remain Dart ^3.12.0 and Flutter >=3.44.0; release validation uses Flutter 3.47.2.

- Make release verification reproducible with job-local Flutter/Dart and native test dependencies, and isolate publication token references from ordinary CI.

## 1.5.1 - Prepare patch release with complete deployment built artifacts

- Fix iOS simulator startup by waiting for its log stream before launching the test application; preserve both SwiftPM and CocoaPods support and workspace/pub-cache native-source resolution.
- Isolate Flutter settings and Android Gradle state per CI job, select Java 17 explicitly, and retain both modern AGP 9 and legacy Android consumers.
- Add bounded native/Web/CLI decompression, including unknown-size and concatenated frames, with a 256 MiB default output limit and valid empty-input frames.
- Use byte-safe native isolate transfers and a dedicated WebAssembly worker; improve CLI argument parsing, stdin/stdout handling, collision protection and native-library resolution.
- Use the canonical reviewed zstd source across all native platforms and keep Apple dependency-manager source sets aligned.
- Generate matching WebAssembly/JavaScript assets and rebuild the complete macOS universal, Linux x64/arm64 and Windows x64/ARM64 CLI library set during deployment preparation.
- Validate one complete retained candidate before production promotion and publish the ten packages in dependency order using GitHub OIDC and the protected pub.dev environment. Copilot owns promotion, tag/release creation, recovery and reconciliation.
- Document artifact retention, exact-commit handoff, runner requirements and the distinction between validation builds and publication outputs.
- Compatibility: requires Dart ^3.12.0 and Flutter >=3.44.0; CI is validated with Flutter 3.47.2. These minimums are higher than the previously published 1.5.0 requirements.

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
