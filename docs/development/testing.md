# Testing Guidelines

This document describes how to run and write tests for the Zstandard plugin and CLI.

## Integration Tests for Platform Packages

Platform-specific packages use **integration tests** that run on real devices, emulators, desktop applications, or Chrome. This gives coverage over the native/WASM boundary instead of only testing Dart mocks.

- **Android**: Tests run in `zstandard_android/example/integration_test/` on an Android emulator.
- **iOS**: Tests run in `zstandard_ios/example/integration_test/` on an iOS simulator.
- **macOS**: Tests run in `zstandard_macos/example/integration_test/` after the native framework is built.
- **Windows**: Tests run in `zstandard_windows/example/integration_test/` after the native DLL is built.
- **Web**: The example integration tests run through `flutter drive` with ChromeDriver. Direct `flutter test -d chrome` is suitable for web unit tests, but Flutter 3.47.2 does not support `integration_test` directly on the Chrome device.

Linux and Windows tests run only on their native OS in CI.

### Prerequisites

1. **Android**: Android SDK with emulator (API 28+). Set `ANDROID_HOME` or `ANDROID_SDK_ROOT`; Linux CI uses software emulation.
2. **iOS**: Xcode with simulators installed.
3. **macOS**: Xcode command-line tools.
4. **Windows**: Visual Studio C++ desktop workload, CMake, and an interactive desktop session for launching the Flutter app.
5. **Web**: Chrome browser.

See [Emulator and simulator setup](emulator-setup.md) for details.

### Running all tests (no skips)

From the repository root:

```bash
./scripts/test_all_integration.sh
```

This runs unit tests for pure Dart packages, then integration tests for Android (emulator), iOS (simulator), macOS (after building the framework), Web (ChromeDriver), and Linux when run on Linux. Set an explicit `ZSTANDARD_SKIP_*` variable only when intentionally running a partial local suite.

### Running individual platform tests

**Android** (starts emulator if needed; first boot can take 2–4 minutes):

```bash
./scripts/test_android_integration.sh
```

To skip Android when running the full suite (e.g. if no emulator or slow machine): `ZSTANDARD_SKIP_ANDROID=1 ./scripts/test_all_integration.sh`. To allow more time for boot: `ZSTANDARD_AVD_BOOT_TIMEOUT=300 ./scripts/test_android_integration.sh`.

**iOS** (boots simulator if needed):

```bash
./scripts/test_ios_integration.sh
```

**macOS** (Flutter builds the app when running tests):

```bash
cd zstandard_macos/example
flutter test integration_test/ -d macos
```

**Web** (Chrome + ChromeDriver):

```bash
./scripts/test_web_integration.sh
```

**Windows** (native desktop app):

```bat
scripts\test_windows_integration.bat
```

## Running Tests

### Main plugin (zstandard)

```bash
cd zstandard
flutter test
```

### Platform interface

```bash
cd zstandard_platform_interface
flutter test
```

### Platform implementations

- **Android, iOS, macOS**: Platform tests live in each package’s `example/integration_test/`. Use the scripts above (e.g. `./scripts/test_android_integration.sh`). The package `test/` directory only contains a pointer test.
- **Linux**: From the package directory, `flutter test` (run on Linux).
- **Windows**: From the package directory, `flutter test` (run on Windows with the built DLL on `PATH`); the example build also runs the native C++ CTest target.
- **Web**: Run `./scripts/test_web_integration.sh`; it runs package web tests when present and the example integration suite through ChromeDriver. The package currently keeps its web coverage in `example/integration_test/`.

### CLI package

```bash
cd zstandard_cli
dart test
```

### All packages (quick run, may skip platform-specific tests)

```bash
./scripts/test_all.sh
```

Use `./scripts/test_all_integration.sh` for full coverage without skips (see above).

### Integration tests (main plugin)

The main plugin’s example app also has integration tests:

```bash
cd zstandard/example
flutter test integration_test/
```

Use `-d <device_id>` to run on a specific device or simulator.

## Test Structure

- **Unit tests**: In each package’s `test/` directory. Use `test()` and `group()` from `package:test` or `package:flutter_test`. Mock the platform when testing the main plugin or platform interface. For Android, iOS, macOS, and Web, the main platform tests have been moved to integration tests.
- **Integration tests**: In each platform example’s `integration_test/` directory. They run on a real device, emulator, simulator, Linux desktop, or Chrome and exercise the full native/WASM stack. CI treats missing infrastructure and test failures as failures.

## Writing Tests

### Platform interface

- **Contract tests**: Verify that the default implementation (method channel) throws `UnimplementedError` for `compress` and `decompress` if not overridden. Verify `getPlatformVersion` behavior when a mock is set.
- **Mock platform**: Implement a fake `ZstandardPlatform` that returns deterministic results and verify that the main plugin (or code under test) behaves correctly when this mock is set as `ZstandardPlatform.instance`.

### Main plugin

- **Singleton**: Verify that `Zstandard()` returns the same instance.
- **Compress/decompress**: With a mock platform, verify that `compress` and `decompress` forward to the platform and return the platform’s result.
- **Extensions**: Test `Uint8List?.compress()` and `decompress()` with null and non-null receiver, and with a mock platform.

### Platform implementations (native)

For Android, iOS, and macOS, platform tests are **integration tests** in `example/integration_test/`. They include:

- **Compression roundtrip**: Small, large, and empty input.
- **Compression levels**: 1, 3, 10, 22.
- **Error handling**: Corrupted or random bytes for decompress; expect `null` or appropriate handling.
- **Edge cases**: Empty input, highly compressible data, large data.
- **Property-based tests**: Roundtrip property with generative input (e.g. kiri_check).
- **Leak tracking**: Where applicable, ensure no leaks after compress/decompress.

Linux and Windows keep unit tests in `test/` that run only when the host OS matches. Web integration tests run in Chrome through `flutter drive` and ChromeDriver.

### CLI

- The existing tests in `zstandard_cli/test/` are a good reference: small/large/empty data, repeated values, min/max compression level. Add tests for invalid compression levels and platform detection if desired.

## Coverage

To collect coverage (when supported):

```bash
cd zstandard
flutter test --coverage
```

View the generated `coverage/lcov.info` with a tool like `lcov` or your IDE. Aim for high coverage on the main plugin and platform interface; platform-specific code may have lower coverage when run on a single host.

## Mutation testing

Mutation testing measures test quality by mutating source code and checking whether tests detect the changes. A mutation score of 90% or above is required.

- **Config**: `mutation_test_config.xml` at repo root (Flutter packages) or `zstandard_cli/mutation_test_config.xml` (CLI).
- **Run for one package** (from repo root): `cd <package> && dart run mutation_test ../mutation_test_config.xml` (use `mutation_test_config.xml` for zstandard_cli).
- **Run for all packages**: `./scripts/run_mutation_test.sh all` (takes a long time).
- **Threshold**: Failure if mutation score &lt; 90%.

## CI

CI runs platform-specific tests as follows:

- **Android**: Starts an emulator, runs `zstandard_android/example` integration tests, then stops the emulator.
- **iOS**: Boots a simulator, runs `zstandard_ios/example` integration tests.
- **macOS**: Builds the native framework (if needed), then runs `zstandard_macos/example` integration tests.
- **Web**: Builds the example with `flutter build web --release` and runs the integration suite through ChromeDriver under Xvfb.
- **Linux**: Runs on the native Linux runner and builds the example with `flutter build linux --debug` before running under Xvfb.
- **Windows**: Builds the example with `flutter build windows --debug`, runs the native CTest target, runs package tests, and launches the example for integration tests.

Ensure your changes do not break these jobs. Add new tests for new behavior and fix any failing tests before submitting a PR.
