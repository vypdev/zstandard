# CI/CD

This document describes the continuous integration and deployment setup for the Zstandard plugin and CLI, including GitHub Actions workflows and how to use them.

## Overview

The repository uses **GitHub Actions** for:

- **PR checks**: Analyze and test each package on pull requests (open or new commits; except to protected branches).
- **Release workflow**: Version bumping, building precompiled CLI libraries, tagging, and publishing to pub.dev.
- **Hotfix workflow**: Expedited fixes and releases when needed.

Workflows are in [`.github/workflows/`](https://github.com/vypdev/zstandard/tree/master/.github/workflows).

## PR check workflows

Each package has a dedicated workflow that runs on pull requests (open or new commits to the PR branch) to non-protected branches:

| Workflow file | Package | Runner | Steps |
|---------------|---------|--------|--------|
| `pr_check_zstandard.yml` | zstandard | self-hosted Linux | Analyze, Test (with coverage), Publish dry run |
| `pr_check_android.yml` | zstandard_android | self-hosted Linux | Analyze, Build APK, Android emulator integration tests, Publish dry run |
| `pr_check_ios.yml` | zstandard_ios | self-hosted macOS ARM64 | Analyze, build, headless simulator launch, SwiftPM and CocoaPods integration tests from checkout and Pub cache, Publish dry run |
| `pr_check_macos.yml` | zstandard_macos | self-hosted macOS ARM64 | Analyze, build, launch, SwiftPM and CocoaPods integration tests from checkout and Pub cache, Publish dry run |
| `pr_check_linux.yml` | zstandard_linux | self-hosted Linux | Analyze, Build Linux app, Linux integration tests, Publish dry run |
| `pr_check_windows.yml` | zstandard_windows | self-hosted Windows X64 | Analyze, build, native C++ tests, Dart tests, Windows integration tests, Publish dry run |
| `pr_check_web.yml` | zstandard_web | self-hosted Linux | Analyze, Build Web app, ChromeDriver integration tests, Publish dry run |
| `pr_check_cli.yml` | zstandard_cli | self-hosted Linux | Analyze, Test (with coverage), Publish dry run |
| `pr_check_platform_interface.yml` | zstandard_platform_interface | self-hosted Linux | Analyze, Test (with coverage), Publish dry run |

There is no dedicated PR check workflow for **zstandard_native** (it has no Dart tests; it mainly ships C source and bindings). It is published in the release workflow after `platform_interface` and before the platform packages that depend on it.

Pull request checks run for pull requests targeting any branch except `master`. Push checks run on `develop` so the branch itself is continuously verified.

**Concurrency**: Only the latest run per branch/PR is kept; in-progress runs are cancelled when new commits are pushed to the PR.

### Coverage

- Flutter packages: `flutter test --coverage` produces `coverage/lcov.info` in the package directory.
- CLI package: `dart test --coverage=coverage` then `dart run coverage:format_coverage` to produce lcov.
- Coverage is uploaded to **Codecov** via the `codecov/codecov-action@v4` step. Upload failures are job failures because coverage reporting is part of the check contract.

### Self-hosted Linux runner contract

The Linux workflows target the repository labels `[self-hosted, Linux]`. The runner account must be able to use passwordless `sudo` so the local composite action at [`.github/actions/setup-linux-dependencies/action.yml`](../../.github/actions/setup-linux-dependencies/action.yml) can install the required packages.

The action installs the common native toolchain (`build-essential`, Clang, CMake, Ninja, `pkg-config`, and `curl`). Desktop jobs additionally install GTK and Xvfb; coverage jobs install `lcov` and `bc`.

Before installing anything, the action repairs an interrupted Debian package
transaction with `dpkg --configure -a` and `apt-get -f install`, then runs the
installation under a host-local lock and verifies the result with
`apt-get check`. This is required because self-hosted runners preserve their
package database between jobs; a cancelled job must not make the next check
fail before the project is even built. If recovery itself fails on a runner,
inspect `dpkg --audit` and the package-manager logs on that host.

Android runners must also provide:

- Android SDK with `platform-tools` and the emulator on the SDK path.
- Java 17. `/dev/kvm` is optional because the current workflow explicitly uses software emulation.
- Network access for the API 30 `aosp_atd` x86_64 system image used by the emulator launcher. Android ATD is intentionally used because it removes background services that are irrelevant to these tests and reduces CPU/memory pressure on the software-only runner.

The Android job builds the example APK before booting the emulator. The Linux job builds the example application before running its integration tests. The Web job installs a matching Chrome/ChromeDriver pair, builds the example, and runs the `flutter drive` integration suite under Xvfb. A missing dependency or failed build is an explicit failure; platform integration tests are not silently skipped in CI.

Android integration tests verify non-empty payloads, exact
`decompress(compress(input))` round-trips, empty input, corruption handling,
all documented compression levels, and deterministic property-based cases.
The Android instrumentation suite repeats the round-trip and invalid-frame
checks directly through JNI against the same shared library loaded by Dart
FFI. The level-22 test uses a small payload because the CI emulator is
software-only; large-content behavior is covered separately.

PR checks pin Flutter 3.47.2. This is intentional: the organisation-level `FLUTTER_VERSION` variable previously selected Flutter 3.41.4, which is below the minimum required by the current root and Android packages.

Apple workflows use the self-hosted ARM64 Mac runner and validate both native dependency managers. iOS simulators are booted through `simctl` without opening the Simulator UI; the iOS job invokes the single integration file explicitly because the example intentionally keeps all iOS checks in one test process. macOS tests run the built app in the runner's logged-in graphical session. Windows uses self-hosted X64 runners and requires a Windows desktop session plus Visual Studio/CMake for native builds and launched integration tests.

### Self-hosted Windows runner contract

Windows jobs target `[self-hosted, Windows, X64]`. The workflow installs and caches the pinned Flutter SDK on each runner, then enables Windows desktop support and verifies CMake. Each runner must provide a Visual Studio C++ desktop toolchain and an interactive desktop session because Flutter's Windows integration tests launch the compiled example application.

The Windows workflow builds and tests the implementation package from the repository and from the published `zstandard_native` package in the Pub cache. Each path runs the native C++ zstd round-trip tests, Dart package tests, and launched Flutter integration tests. A separate job runs the federated `zstandard/example` application to verify the public plugin entry point on Windows.

## Release workflow

**File**: [`.github/workflows/release_workflow.yml`](https://github.com/vypdev/zstandard/blob/master/.github/workflows/release_workflow.yml)

Triggered manually (**workflow_dispatch**) with inputs such as version, title, changelog, and optional issue reference.

**Main phases**:

1. **Prepare candidate**: Require `release/x.y.z`, bump all package versions/dependencies, pin SwiftPM to the exact version, update CocoaPods podspecs, copy CHANGELOG, and regenerate WebAssembly from `zstandard_native/src/zstd/`.
2. **Build precompiled CLI libraries** (on platform-specific runners):
   - **macOS**: Cross-compile x86_64 and ARM64 from the canonical C source, merge with `lipo` into a universal `libzstandard_macos.dylib`, and assert both slices; commit.
   - **Linux**: Build x86_64 and ARM64 `.so` files from the canonical C source and assert ELF machine headers; commit.
   - **Windows**: Detect the installed Visual Studio generator, build x64 and ARM64 DLLs, and assert PE machine headers; commit.
3. **Candidate verification**: Build and execute Android (AGP 9 and legacy), Linux, Web, Windows, and both Apple dependency-manager variants. Candidate jobs use local overrides until their pub.dev versions exist.
4. **Tag and release**: Create one immutable git tag and a draft GitHub release with changelog and checksums.
5. **Publish**: Publish packages to pub.dev in dependency order: **platform_interface → zstandard_native** (shared C source) **→ platform implementations** (android, ios, macos, linux, windows, web) **→ zstandard_cli → zstandard**.
6. **Verify and finalize**: Verify all ten package versions through the pub.dev API, finalize the draft release, and notify. A separate workflow integrates the release branch into `develop` and `master`.

The workflow uses **self-hosted** runners for macOS, Linux, and Windows to build native binaries and run platform-specific steps.

## Hotfix workflow

**File**: [`.github/workflows/hotfix_workflow.yml`](https://github.com/vypdev/zstandard/blob/master/.github/workflows/hotfix_workflow.yml)

Used for expedited fixes (e.g. security or critical bugs). Typically triggered manually and may skip some steps or use a shorter path to release. See the workflow file and team docs for details.

## Running checks locally

To mimic CI locally:

- **Analyze**: `flutter analyze` or `dart analyze` in each package.
- **Test**: `flutter test` or `dart test` in each package.
- **Build**: `flutter build apk --debug`, `flutter build linux --debug`, or `flutter build web --release` for the platform examples before integration tests.
- **Test with coverage**: `flutter test --coverage` (Flutter) or `dart test --coverage=coverage` then format (CLI).
- **All packages**: Use the [test scripts](../../scripts/) (e.g. `./scripts/test_all.sh` or `scripts\test_all.bat`).

## Build automation scripts

Scripts under [**scripts/**](https://github.com/vypdev/zstandard/tree/master/scripts) help build native libraries and run tests locally:

- `build_macos.sh`, `build_linux.sh`, `build_windows.bat`: Build precompiled zstd libraries for the CLI.
- `build_android.sh`, `build_ios.sh`: Build or prepare the Android/iOS plugin.
- Swift Package Manager consumes the canonical zstd C source through the repository-level `Package.swift`; the sync scripts refresh only the ignored `Classes/zstd/` compatibility trees used by CocoaPods.
- `regenerate_bindings.sh`: Regenerate FFI bindings (ffigen) for all platform packages after zstd source updates.
- `test_all.sh` / `test_all.bat`: Run tests in all packages.
- `coverage_report.sh` / `coverage_report.bat`: Generate coverage reports.

See the script contents and [Building](building.md) for requirements (CMake, NDK, Xcode, etc.).

## See also

- [Release process](release-process.md)
- [Testing](testing.md)
- [Building](building.md)
