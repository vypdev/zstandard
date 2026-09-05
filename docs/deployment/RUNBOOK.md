# Deployment and recovery runbook

This runbook describes how to run a release, what the pipeline does, and how to recover when a release fails.

## Prerequisites

- **Pub.dev**: Each runner that publishes (macOS, Linux, Windows) must have run `dart pub login` so that `dart pub publish` can authenticate. Prefer pub.dev trusted publishing with GitHub OIDC when it is configured for all packages.
- **Secrets** (in GitHub repo settings): `PAT` is only used by the optional deployment notification; `GITHUB_TOKEN` creates the tag, draft release, and release assets.
- **Variables** (optional): `DEBUG`, `OPEN_ROUTER_MODEL` (or similar) if your notification/tooling uses them.

## Running a release

1. Create or check out a branch named exactly `release/x.y.z`, for example `release/1.5.1`.
2. Update **CHANGELOG.md** at the repo root with the new version and user-facing changes.
3. In GitHub: **Actions → Task - Release → Run workflow**.
4. Fill inputs:
   - **version**: Semver, e.g. `1.5.1` (do not include `v`; it must match the release branch).
   - **title**: Short release title.
   - **changelog**: Summary (or paste from CHANGELOG).
   - **issue**: Launcher/issue reference (e.g. `-1` if not used).
   - **resume**: Leave disabled for a new release. Enable it only when a previous run already created `v<version>` and stopped during publication.
5. Run the workflow. It will:
   - Validate the release branch, version, and remote tag state.
   - Copy CHANGELOG into all packages.
   - Update all `pubspec.yaml` versions/dependencies, pin SwiftPM to the exact release, and update both CocoaPods podspec versions.
   - Regenerate WebAssembly from the canonical C source and verify all committed copies are synchronized.
   - Build and verify macOS universal, Linux x86_64/arm64, and Windows x64/ARM64 CLI libraries.
   - Run candidate checks for Android (AGP 9 and legacy), Linux, Web, Windows, and Apple with both SwiftPM and CocoaPods. Apple jobs use ARM64; Intel Apple execution is not claimed.
   - Create one immutable tag and a draft GitHub release. Every later job checks out that tag, never a moving branch.
   - Publish to pub.dev in order: **platform_interface → zstandard_native → platform packages (parallel) → CLI → zstandard**, with one common dry-run barrier for all platform packages.
   - Skip already published package versions safely when resuming, verify all ten versions through the pub.dev API, finalize the draft release, and then notify.

The release workflow only prepares and publishes `release/x.y.z`. A separate integration workflow brings the completed release into `develop` and `master`; this workflow does not alter either branch or their rulesets.

## Dependency order (for manual publish)

If you must publish manually (e.g. after a partial failure), use this order:

```text
zstandard_platform_interface
  → zstandard_native
  → zstandard_android, zstandard_ios, zstandard_web, zstandard_macos, zstandard_windows, zstandard_linux
  → zstandard_cli
  → zstandard
```

**zstandard_native** contains the shared C source; all native platform packages and the CLI depend on it, so it must be published before them.

From repo root, with credentials configured:

```bash
# 1. Platform interface
cd zstandard_platform_interface && dart pub publish -f && cd ../..

# 2. Native (shared C source — required by platform packages and CLI)
cd zstandard_native && dart pub publish -f && cd ../..

# 3. Platforms (any order after zstandard_native)
for pkg in zstandard_android zstandard_ios zstandard_web zstandard_macos zstandard_windows zstandard_linux; do
  (cd $pkg && dart pub publish -f) && cd ../..
done

# 4. CLI
cd zstandard_cli && dart pub publish -f && cd ../..

# 5. Main plugin
cd zstandard && dart pub publish -f && cd ../..
```

## When a release fails

- **pub.dev does not allow deleting or overwriting published versions.** Fix the cause and rerun the workflow with the same branch/version and `resume: true`. The workflow checks pub.dev before publishing and never blindly repeats an immutable upload. If the candidate itself must change after the tag was created, use a new patch version; do not move the tag.

- The workflow includes a **Release recovery guide** job that runs when any preparation, candidate, publication, verification, or finalization job fails. It writes the recovery mode to the GitHub Actions job summary.

- **Common causes of failure**
  - **Credentials**: Runner not logged in to pub.dev. On each publishing runner (macOS, Linux, Windows), run `dart pub login` and ensure the account has publish rights for the packages.
  - **Dependency not found**: A package (e.g. `zstandard_platform_interface`) was just published and pub.dev has not indexed it yet. The workflow waits up to ~10 minutes (with backoff) and verifies via the pub.dev API; if it still fails, wait a bit and re-run the same version.
  - **Tests or analyze before the tag**: Fix the release branch and rerun with `resume: false` while no tag exists.
  - **Tests or analyze after the tag**: The candidate is immutable; create a new patch release.

## Building precompiled CLI libraries (release workflow)

The canonical source is **`zstandard_native/src/zstd/`**. The release workflow builds directly from that path through each CMake builder; it does not copy or maintain a second `zstd` tree in `zstandard_cli`. The macOS job cross-compiles x86_64 and arm64 on Apple Silicon and joins them into one universal library. Linux and Windows jobs assert both architecture markers before committing artifacts.

The Windows job detects the installed Visual Studio CMake generator, so it is not coupled to a specific edition or to a hard-coded Visual Studio 2022 path. The runner still needs the C++ desktop workload, CMake, and ARM64 build tools.

## Updating the zstd (C library) version

The canonical zstd C source lives in **`zstandard_native/src/zstd/`**. To upgrade:

1. From the repo root, run:
   ```bash
   ./scripts/update_zstd.sh        # latest from dev (upstream default)
   ./scripts/update_zstd.sh v1.5.7   # or a specific tag/branch
   ```
   This fetches from [facebook/zstd](https://github.com/facebook/zstd) and updates `zstandard_native/src/zstd/`.
2. Run `zstandard_ios/scripts/sync_zstd.sh` and `zstandard_macos/scripts/sync_zstd.sh` (from repo root) to refresh the ignored compatibility trees used by CocoaPods. Swift Package Manager consumes the canonical source through the repository-level `Package.swift` and does not need copied Apple trees.
3. Optionally run `./scripts/regenerate_bindings.sh` and commit any changed `*_bindings_generated.dart` files.
4. Commit the changes. For releases, the workflow builds precompiled CLI libraries; see `.github/workflows/release_workflow.yml` for how each runner obtains the zstd source (e.g. from the repo or a pinned ref).

## Related docs

- [Release process](../development/release-process.md) – versioning and pre-release checklist.
- [SECURITY.md](../../SECURITY.md) – reporting vulnerabilities and CI security practices.
