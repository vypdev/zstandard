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
   - **version**: Semver, e.g. `1.3.30` (do not include `v`).
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
   - Publish to pub.dev in order: **platform_interface → platform packages (parallel) → cli → zstandard**, with verification after each publish.
   - Notify on success (or run the rollback guide job on failure).

## Dependency order (for manual publish)

If you must publish manually (e.g. after a partial failure), use this order:

```text
zstandard_platform_interface
  → zstandard_android, zstandard_ios, zstandard_web, zstandard_macos, zstandard_windows, zstandard_linux
  → zstandard_cli
  → zstandard
```

From repo root, with credentials configured:

```bash
# 1. Platform interface
cd zstandard_platform_interface && dart pub publish -f && cd ../..

# 2. Platforms (any order after platform_interface)
for pkg in zstandard_android zstandard_ios zstandard_web zstandard_macos zstandard_windows zstandard_linux; do
  (cd $pkg && dart pub publish -f) && cd ../..
done

# 3. CLI
cd zstandard_cli && dart pub publish -f && cd ../..

# 4. Main plugin
cd zstandard && dart pub publish -f && cd ../..
```

## When a release fails

- **pub.dev does not allow deleting or overwriting published versions.** If some packages were published and others failed, you have two options:
  1. **Fix the failure** (e.g. fix a test, fix credentials, fix network) and **re-run the workflow** with the **same version**. Only the steps that did not yet succeed will effectively run again (e.g. later packages can now resolve the already-published ones).
  2. **Bump to a new patch version** (e.g. 1.3.30 → 1.3.31), fix the issue, and run a new release so all packages are published under the new version.

- The workflow includes a **Rollback / recovery guide** job that runs when any publish job fails. It writes a short recovery summary to the GitHub Actions job summary. Use that and this runbook to decide next steps.

- **Common causes of failure**
  - **Credentials**: Runner not logged in to pub.dev. On each publishing runner (macOS, Linux, Windows), run `dart pub login` and ensure the account has publish rights for the packages.
  - **Dependency not found**: A package (e.g. `zstandard_platform_interface`) was just published and pub.dev has not indexed it yet. The workflow waits up to ~10 minutes (with backoff) and verifies via the pub.dev API; if it still fails, wait a bit and re-run the same version.
  - **Tests or analyze**: Fix the failing package locally, commit, and re-run the release with the same version.

## Updating the zstd (C library) version

The workflow uses the **zstd** directory at the **repo root** (no download in CI). To upgrade:

1. Replace or update the contents of the root `zstd/` directory (e.g. clone [facebook/zstd](https://github.com/facebook/zstd), checkout the desired tag like `v1.5.7`, and copy its contents over `zstd/`, or use a git submodule).
2. Ensure `zstd/lib/` contains the library sources the builders expect.
3. Commit the changes and run the release as usual; the workflow will copy `zstd/lib/*` into `zstandard_cli/src/` and build.

## Related docs

- [Release process](../development/release-process.md) – versioning and pre-release checklist.
- [SECURITY.md](../../SECURITY.md) – reporting vulnerabilities and CI security practices.
