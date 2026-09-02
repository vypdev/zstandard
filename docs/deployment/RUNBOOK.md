# Deployment and recovery runbook

This runbook describes how to run a release, what the pipeline does, and how to recover when a release fails.

## Prerequisites

- **Pub.dev**: Each runner that publishes (macOS, Linux, Windows) must have run `dart pub login` so that `dart pub publish` can authenticate. Credentials are read from the usual Dart config location on each machine.
- **Secrets** (in GitHub repo settings): `PAT` (personal access token with repo scope), if used by the release workflow for tagging/notifications.
- **Variables** (optional): `DEBUG`, `OPEN_ROUTER_MODEL` (or similar) if your notification/tooling uses them.

## Running a release

1. **Update CHANGELOG.md** at the repo root with the new version and user-facing changes.
2. In GitHub: **Actions → Task - Release → Run workflow**.
3. Fill inputs:
   - **version**: Semver, e.g. `1.5.0` (do not include `v`).
   - **title**: Short release title.
   - **changelog**: Summary (or paste from CHANGELOG).
   - **issue**: Launcher/issue reference (e.g. `-1` if not used).
4. Run the workflow. It will:
   - Validate that tag `v<version>` does not exist.
   - Copy CHANGELOG into all packages.
   - Update all `pubspec.yaml` version and dependency versions (via `.github/scripts/update_versions.dart`).
   - Commit and push version bumps.
   - Build native libs (macOS, Linux, Windows) from pinned `facebook/zstd` ref.
   - Create tag and GitHub release.
   - Publish to pub.dev in order: **platform_interface → zstandard_native → platform packages (parallel) → cli → zstandard**, with verification after each publish.
   - Notify on success (or run the rollback guide job on failure).

## Dependency order (for manual publish)

If you must publish manually (e.g. after a partial failure), use this order:

```text
zstandard_platform_interface
  → zstandard_native
  → zstandard_android, zstandard_ios, zstandard_web, zstandard_macos, zstandard_windows, zstandard_linux
  → zstandard_cli
  → zstandard
```

**zstandard_native** contains the shared C source (facebook/zstd); all native platform packages and the CLI depend on it, so it must be published before them.

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

- **pub.dev does not allow deleting or overwriting published versions.** If some packages were published and others failed, you have two options:
  1. **Fix the failure** (e.g. fix a test, fix credentials, fix network) and **re-run the workflow** with the **same version**. Only the steps that did not yet succeed will effectively run again (e.g. later packages can now resolve the already-published ones).
  2. **Bump to a new patch version** (e.g. 1.5.0 → 1.5.1), fix the issue, and run a new release so all packages are published under the new version.

- The workflow includes a **Rollback / recovery guide** job that runs when any publish job fails. It writes a short recovery summary to the GitHub Actions job summary. Use that and this runbook to decide next steps.

- **Common causes of failure**
  - **Credentials**: Runner not logged in to pub.dev. On each publishing runner (macOS, Linux, Windows), run `dart pub login` and ensure the account has publish rights for the packages.
  - **Dependency not found**: A package (e.g. `zstandard_platform_interface`) was just published and pub.dev has not indexed it yet. The workflow waits up to ~10 minutes (with backoff) and verifies via the pub.dev API; if it still fails, wait a bit and re-run the same version.
  - **Tests or analyze**: Fix the failing package locally, commit, and re-run the release with the same version.

## Building precompiled CLI libraries (release workflow)

The release workflow jobs that build macOS, Linux, and Windows CLI libraries currently run `cp -r zstd zstandard_cli/`, expecting a **`zstd`** directory at the repository root. The canonical source in the repo is **`zstandard_native/src/zstd/`**. If the "Copy zstd from repo root" step fails (e.g. in a normal clone there is no `zstd` at root), update the workflow to copy from `zstandard_native/src/zstd` into `zstandard_cli/zstd` instead, or ensure the runner has `zstd` at root (e.g. symlink or copy from `zstandard_native/src/zstd`).

## Updating the zstd (C library) version

The canonical zstd C source lives in **`zstandard_native/src/zstd/`**. To upgrade:

1. From the repo root, run:
   ```bash
   ./scripts/update_zstd.sh        # latest from dev (upstream default)
   ./scripts/update_zstd.sh v1.5.7   # or a specific tag/branch
   ```
   This fetches from [facebook/zstd](https://github.com/facebook/zstd) and updates `zstandard_native/src/zstd/`.
2. Run `zstandard_ios/scripts/sync_zstd.sh` and `zstandard_macos/scripts/sync_zstd.sh` (from repo root) so iOS/macOS have the updated source for CocoaPods.
3. Optionally run `./scripts/regenerate_bindings.sh` and commit any changed `*_bindings_generated.dart` files.
4. Commit the changes. For releases, the workflow builds precompiled CLI libraries; see `.github/workflows/release_workflow.yml` for how each runner obtains the zstd source (e.g. from the repo or a pinned ref).

## Related docs

- [Release process](../development/release-process.md) – versioning and pre-release checklist.
- [SECURITY.md](../../SECURITY.md) – reporting vulnerabilities and CI security practices.
