# Release Process

This document outlines how releases of the Zstandard plugin and CLI are prepared and published. The project uses a centralized version and CHANGELOG across all packages.

## Versioning

- All packages (zstandard, zstandard_platform_interface, **zstandard_native**, zstandard_android, zstandard_ios, zstandard_macos, zstandard_linux, zstandard_windows, zstandard_web, zstandard_cli) share the **same version number** (e.g. 1.5.0). **zstandard_native** contains the shared C source and is published so that platform packages and the CLI can depend on it from pub.dev.
- Follow [semantic versioning](https://semver.org/): MAJOR.MINOR.PATCH. Bump:
  - **MAJOR** for incompatible API changes.
  - **MINOR** for new backward-compatible features.
  - **PATCH** for backward-compatible bug fixes.

## Pre-Release Checklist

- [ ] All tests pass (`flutter test` / `dart test` in each package).
- [ ] `flutter analyze` (or `dart analyze`) reports no errors in the packages you are releasing.
- [ ] CHANGELOG.md is updated with user-facing changes for the release.
- [ ] Version in root and in each package’s `pubspec.yaml` is updated to the new version.
- [ ] Inter-package dependencies use the new version (e.g. `zstandard_android` depends on `zstandard_platform_interface: ^x.y.z` and `zstandard_native: ^x.y.z`).

## Release Workflow (CI)

The project uses a **Release** workflow (e.g. GitHub Actions “Task - Release”) that:

1. **Validates** that the release version and tag do not already exist.
2. **Copies** CHANGELOG.md into each package (including zstandard_native).
3. **Updates** `version:` and dependency versions in every package’s `pubspec.yaml`.
4. **Publishes** packages to pub.dev in dependency order: **platform_interface → zstandard_native** (shared C source) **→ platform implementations** (android, ios, macos, linux, windows, web) **→ zstandard and zstandard_cli**.
5. **Creates** a git tag (e.g. `v1.5.0`) and possibly a GitHub release.

The workflow is typically triggered manually (workflow_dispatch) with inputs such as:

- **version**: e.g. `1.5.0`
- **title**: Release title
- **changelog**: Summary of changes
- **issue**: Optional launcher issue reference

## Manual Steps (if not using full automation)

If you need to release without the full workflow:

1. Update **CHANGELOG.md** at the repo root with the new version and list of changes.
2. Update **version** in every package’s **pubspec.yaml** to the new version.
3. Update **dependency versions** in each package that depends on another (e.g. `zstandard_android` depends on `zstandard_platform_interface: ^X.Y.Z` — set to the new version).
4. Copy **CHANGELOG.md** into each package’s directory if the project keeps a copy per package.
5. **Publish** in dependency order:
   - `zstandard_platform_interface`
   - `zstandard_native` (platform packages and CLI depend on it)
   - Platform packages (android, ios, macos, linux, windows, web)
   - `zstandard`
   - `zstandard_cli`
6. **Tag** the release: `git tag vX.Y.Z` (e.g. `v1.5.0`) and push the tag.
7. **Create** a GitHub release from the tag and paste the changelog.

## Publishing to pub.dev

- Use `dart pub publish` (or `flutter pub publish`) from each package directory. Confirm the package name and version when prompted.
- Ensure you are logged in (`dart pub login`) and have permissions to publish the package.
- Publish in order so that dependencies are available: platform_interface first, then **zstandard_native**, then platform implementations, then zstandard and zstandard_cli.

## After Release

- Bump the development version in `pubspec.yaml` files if the project uses a separate “next” version (e.g. 1.3.30+1 or 1.5.0-dev).
- Add an “Unreleased” or “Next” section in CHANGELOG.md for the next release.
- Announce the release (e.g. GitHub release notes, changelog link) as appropriate.

## Hotfixes

For critical fixes, the project may use a **hotfix** workflow (see `.github/workflows/hotfix_workflow.yml` and issue templates). Follow the same versioning and publish order; use a PATCH bump (e.g. 1.5.0 → 1.4.1).
