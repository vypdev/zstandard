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
| `pr_check_zstandard.yml` | zstandard | self-hosted macOS | Analyze, Test (with coverage), Publish dry run |
| `pr_check_android.yml` | zstandard_android | self-hosted macOS | Analyze, Test (with coverage), Publish dry run |
| `pr_check_ios.yml` | zstandard_ios | self-hosted macOS | Analyze, Test (with coverage), Publish dry run |
| `pr_check_macos.yml` | zstandard_macos | self-hosted macOS | Analyze, Test (with coverage), Publish dry run |
| `pr_check_linux.yml` | zstandard_linux | self-hosted Linux | Analyze, Test (with coverage), Publish dry run |
| `pr_check_windows.yml` | zstandard_windows | self-hosted Windows | Analyze, Test (with coverage), Publish dry run |
| `pr_check_web.yml` | zstandard_web | self-hosted macOS | Analyze, Test (with coverage), Publish dry run |
| `pr_check_cli.yml` | zstandard_cli | self-hosted macOS | Analyze, Test (with coverage), Publish dry run |
| `pr_check_platform_interface.yml` | zstandard_platform_interface | self-hosted macOS | Analyze, Test (with coverage), Publish dry run |

There is no dedicated PR check workflow for **zstandard_native** (it has no Dart tests; it mainly ships C source and bindings). It is published in the release workflow after `platform_interface` and before the platform packages that depend on it.

**Branches excluded** from running these checks: `develop`, `release/**`, `hotfix/**`, `master`.

**Concurrency**: Only the latest run per branch/PR is kept; in-progress runs are cancelled when new commits are pushed to the PR.

### Coverage

- Flutter packages: `flutter test --coverage` produces `coverage/lcov.info` in the package directory.
- CLI package: `dart test --coverage=coverage` then `dart run coverage:format_coverage` to produce lcov.
- Coverage is uploaded to **Codecov** (or similar) via the `codecov/codecov-action@v4` step when the workflow runs. Upload failure does not fail the job (`fail_ci_if_error: false`).

## Release workflow

**File**: [`.github/workflows/release_workflow.yml`](https://github.com/vypdev/zstandard/blob/master/.github/workflows/release_workflow.yml)

Triggered manually (**workflow_dispatch**) with inputs such as version, title, changelog, and optional issue reference.

**Main phases**:

1. **Update files**: Bump version and dependency versions in all packages; copy CHANGELOG; commit.
2. **Build precompiled CLI libraries** (on platform-specific runners):
   - **macOS**: Clone facebook/zstd, build Intel and ARM64 libs, merge with `lipo` into a universal `libzstandard_macos.dylib`; commit.
   - **Linux**: Clone zstd, build x64 and ARM64 `.so`; commit.
   - **Windows**: Clone zstd, build x64 and ARM64 DLLs; commit.
3. **Tag and release**: Create git tag (e.g. `v1.5.0`) and GitHub release with changelog.
4. **Publish**: Publish packages to pub.dev in dependency order: **platform_interface → zstandard_native** (shared C source) **→ platform implementations** (android, ios, macos, linux, windows, web) **→ zstandard_cli and zstandard**.

The workflow uses **self-hosted** runners for macOS, Linux, and Windows to build native binaries and run platform-specific steps.

## Hotfix workflow

**File**: [`.github/workflows/hotfix_workflow.yml`](https://github.com/vypdev/zstandard/blob/master/.github/workflows/hotfix_workflow.yml)

Used for expedited fixes (e.g. security or critical bugs). Typically triggered manually and may skip some steps or use a shorter path to release. See the workflow file and team docs for details.

## Running checks locally

To mimic CI locally:

- **Analyze**: `flutter analyze` or `dart analyze` in each package.
- **Test**: `flutter test` or `dart test` in each package.
- **Test with coverage**: `flutter test --coverage` (Flutter) or `dart test --coverage=coverage` then format (CLI).
- **All packages**: Use the [test scripts](../../scripts/) (e.g. `./scripts/test_all.sh` or `scripts\test_all.bat`).

## Build automation scripts

Scripts under [**scripts/**](https://github.com/vypdev/zstandard/tree/master/scripts) help build native libraries and run tests locally:

- `build_macos.sh`, `build_linux.sh`, `build_windows.bat`: Build precompiled zstd libraries for the CLI.
- `build_android.sh`, `build_ios.sh`: Build or prepare the Android/iOS plugin.
- `sync_zstd_ios_macos.sh`: Sync the canonical zstd C source (`zstandard_native/src/zstd/`) into the iOS and macOS plugin `Classes/zstd/` trees.
- `regenerate_bindings.sh`: Regenerate FFI bindings (ffigen) for all platform packages after zstd source updates.
- `test_all.sh` / `test_all.bat`: Run tests in all packages.
- `coverage_report.sh` / `coverage_report.bat`: Generate coverage reports.

See the script contents and [Building](building.md) for requirements (CMake, NDK, Xcode, etc.).

## See also

- [Release process](release-process.md)
- [Testing](testing.md)
- [Building](building.md)
