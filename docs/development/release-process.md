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
- [ ] Every published package description is between 50 and 180 characters and uses HTTPS metadata URLs.
- [ ] `dart pub publish --dry-run` is clean for every package; verify that the iOS and macOS archives contain their `Package.swift` manifests.
- [ ] Run `pana` against a copy of the main package and review its report before publishing.

## Release Workflow (CI)

The project uses a **Release** workflow (GitHub Actions “Task - Release”) that runs from a `release/x.y.z` branch and:

1. **Validates** that the branch matches the requested version and that the tag is available.
2. **Copies** CHANGELOG.md into each package (including zstandard_native).
3. **Updates** `version:` and dependency versions in every package’s `pubspec.yaml`, pins Apple SwiftPM to the exact release, and synchronizes CocoaPods podspec versions.
4. **Regenerates and verifies** WebAssembly from the canonical `zstandard_native/src/zstd/` source.
5. **Builds and verifies** CLI libraries for macOS universal, Linux x86_64/arm64, and Windows x64/ARM64.
6. **Runs candidate builds and integration tests** for Android (AGP 9 and legacy), Linux, Web, Windows, and Apple (SwiftPM and CocoaPods on ARM64 macOS).
7. **Creates** one immutable git tag and a draft GitHub release. All publication jobs check out that tag.
8. **Publishes** packages to pub.dev in dependency order: **platform_interface → zstandard_native** (shared C source) **→ platform implementations** (android, ios, macos, linux, windows, web) **→ zstandard_cli → zstandard**.

The workflow is typically triggered manually (workflow_dispatch) with inputs such as:

- **version**: e.g. `1.5.0`
- **title**: Release title
- **changelog**: Summary of changes
- **issue**: Optional launcher issue reference
- **resume**: Set to `true` only to continue a partial release whose immutable tag already exists.

## Manual Steps (if not using full automation)

If you need to release without the full workflow:

1. Create `release/x.y.z` and update **CHANGELOG.md** at the repo root with the new version and list of changes.
2. Update **version** in every package’s **pubspec.yaml** to the new version.
3. Update **dependency versions** in each package that depends on another (e.g. `zstandard_android` depends on `zstandard_platform_interface: ^X.Y.Z` — set to the new version).
4. Copy **CHANGELOG.md** into each package’s directory if the project keeps a copy per package.
5. **Publish** in dependency order:
   - `zstandard_platform_interface`
   - `zstandard_native` (platform packages and CLI depend on it)
   - Platform packages (android, ios, macos, linux, windows, web)
   - `zstandard_cli`
   - `zstandard`
6. **Tag** the release only after candidate checks: `git tag vX.Y.Z` (e.g. `v1.5.0`) and push the tag.
7. **Create** a draft GitHub release, upload checksums/package archives, and finalize it only after pub.dev verification.

After publication, a separate workflow integrates the release branch into `develop` and `master`. The release workflow does not alter either branch or their rulesets.

## Publishing to pub.dev

- Use `dart pub publish` (or `flutter pub publish`) from each package directory. Confirm the package name and version when prompted.
- Ensure you are logged in (`dart pub login`) and have permissions to publish the package. Prefer pub.dev trusted publishing with GitHub OIDC once configured for all packages.
- Publish in order so that dependencies are available: platform_interface first, then **zstandard_native**, then platform implementations, then zstandard and zstandard_cli.

## After Release

- Bump the development version in `pubspec.yaml` files if the project uses a separate “next” version (e.g. 1.3.30+1 or 1.5.0-dev).
- Add an “Unreleased” or “Next” section in CHANGELOG.md for the next release.
- Announce the release (e.g. GitHub release notes, changelog link) as appropriate.

## Hotfixes

For critical fixes, the project may use a **hotfix** workflow (see `.github/workflows/hotfix_workflow.yml` and issue templates). Follow the same versioning and publish order; use a PATCH bump (e.g. 1.5.0 → 1.4.1).
