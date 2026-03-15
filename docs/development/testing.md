# Testing Guidelines

This document describes how to run and write tests for the Zstandard plugin and CLI.

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

From each platform package directory:

```bash
cd zstandard_android   # or ios, macos, linux, windows, web
flutter test
```

### CLI package

```bash
cd zstandard_cli
dart test
```

### All packages (from repo root)

You can run tests in each package in sequence, or use a script if the project provides one. Example:

```bash
for dir in zstandard zstandard_platform_interface zstandard_android zstandard_ios zstandard_macos zstandard_linux zstandard_windows zstandard_web zstandard_cli; do
  if [ -d "$dir" ]; then
    (cd "$dir" && flutter test 2>/dev/null || dart test 2>/dev/null) || true
  fi
done
```

### Integration tests

Integration tests run inside the example app on a device or simulator.

```bash
cd zstandard/example
flutter test integration_test/
```

For a specific platform:

```bash
flutter test integration_test/ -d <device_id>
```

Web integration tests may require running with a browser (e.g. `flutter test integration_test/ -d chrome`).

## Test Structure

- **Unit tests**: In each package’s `test/` directory. Use `test()` and `group()` from `package:test` or `package:flutter_test`. Mock the platform when testing the main plugin or platform interface.
- **Integration tests**: In the example app’s `integration_test/` directory. These run on a real (or emulated) device and exercise the full plugin stack.

## Writing Tests

### Platform interface

- **Contract tests**: Verify that the default implementation (method channel) throws `UnimplementedError` for `compress` and `decompress` if not overridden. Verify `getPlatformVersion` behavior when a mock is set.
- **Mock platform**: Implement a fake `ZstandardPlatform` that returns deterministic results and verify that the main plugin (or code under test) behaves correctly when this mock is set as `ZstandardPlatform.instance`.

### Main plugin

- **Singleton**: Verify that `Zstandard()` returns the same instance.
- **Compress/decompress**: With a mock platform, verify that `compress` and `decompress` forward to the platform and return the platform’s result.
- **Extensions**: Test `Uint8List?.compress()` and `decompress()` with null and non-null receiver, and with a mock platform.

### Platform implementations (native)

- **Compression roundtrip**: For the platform’s implementation class (e.g. `ZstandardLinux`), test that compressing then decompressing returns the original data for small, large, and empty input.
- **Compression levels**: Test levels 1, 3, 10, 22.
- **Error handling**: Test invalid input (e.g. corrupted data for decompress); expect `null` or appropriate handling.
- **Edge cases**: Empty input, highly compressible data (e.g. repeated bytes), large data.

These tests may be skipped or stubbed when the native library is not available (e.g. on a host that cannot load the Linux .so). Use `skip` or platform checks if needed.

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

The project’s CI (e.g. GitHub Actions) should run `flutter test` (or `dart test`) for the relevant packages. Ensure your changes do not break these jobs. Add new tests for new behavior and fix any failing tests before submitting a PR.
