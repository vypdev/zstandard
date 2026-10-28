# Release Process

All ten packages share one stable `MAJOR.MINOR.PATCH` version. Copilot owns
issue admission, managed branches, production promotion, tags, release
receipts and reconciliation. The package workflows supply build, test and
pub.dev publication steps. Do not create a competing branch or merge flow.

## Prerequisites

- Configure automated publishing for **each** package on pub.dev: repository
  `vypdev/zstandard`, tag pattern `v{{version}}`, required environment `pub.dev`.
  These settings are private to package administration; a successful public
  API lookup does not prove that publishing is authorized.
- Protect the GitHub `pub.dev` environment with a maintainer reviewer and a
  tag-only `v*` deployment policy. There is no persistent pub token.
- Require PRs and `Pull Request Safety Gate` on `master` and `develop`, with
  deletion/non-fast-forward protection. Retain merge commits for Copilot's
  production-lineage reconciliation. Enable dismissal of stale approvals on
  new pushes and keep effective branch rules readable to Copilot's approval
  observer. Do not apply a blanket deletion ban to
  managed branches: Copilot owns their final cleanup.
- Protect stable version tags against update/deletion. Tag creation remains
  available to the authorized Copilot publisher.
- Keep installed Copilot credentials, workflows, Variables and branch ownership
  intact. Allow Actions to create PRs. Bot-created PR checks may need a
  maintainer to select **Approve workflows to run**.
- Ensure trusted Linux, Apple Silicon and Windows runners are available with
  build dependencies. Product jobs provision Flutter 3.47.2.

## Choose the release version

For a patch release, use the installed Release form with **Release Type:
Patch** and **Release Version: Automatic**. Copilot resolves the next patch
from the latest stable tag; for example, `v1.5.1` advances to `1.5.2`. Record
the resolved version in the issue's control center before starting deployment.

The release notes must announce the current minimums: Dart `^3.12.0` and
Flutter `>=3.44.0`, compared with Dart `^3.6.0` and Flutter `>=3.3.0` in
published 1.5.0. CI uses Flutter 3.47.2. Selecting a patch does not change these
requirements. Package versions and release changelogs are updated by deployment
preparation; do not bump or generate them locally before starting that phase.

## Prepare and promote

1. Open a Release issue with all installed fields. A maintainer adds
   `in-progress`; wait for the exact linked `release/X.Y.Z` and `branched`.
2. Once explicitly authorized to start the release, use the installed `deploy`
   launcher. Copilot dispatches `release_workflow.yml` in `prepare` mode.
   Do not dispatch publication or create a tag manually.
3. Preparation updates versions, CLI version, changelogs, SwiftPM pins and
   podspecs, then regenerates all four Web artifacts from canonical C source
   with the pinned Emscripten toolchain.
4. Native jobs build macOS universal, Linux x64/arm64 and Windows x64/arm64
   libraries in that order. Each job commits its outputs to the managed
   release branch and passes its exact commit to the next job. Unchanged
   outputs can be retried; a moved remote rejects a push. No package is
   published while this build chain is running.
   The Windows CLI producer uses GitHub's standard `windows-2025` image with
   both MSVC toolsets; it does not need Flutter to compile the C libraries.
   Windows application validation runs on the trusted self-hosted desktops.
5. All candidate tests check out the final native-build commit. Static,
   formatting, package, platform release-build and integration gates must pass.
   Resolve all ten packages against the local candidate before formatting,
   so each formatter uses its declared Dart language version. Linux package
   tests load the plugin from the freshly built release bundle, and native
   CTest runs before integration retires Flutter's temporary test entry point.
   Native test discovery is enabled at the example's CMake root; an empty
   CTest suite fails both release and normal Linux CI.
   Web integration starts its driver inside Xvfb without relying on exported
   Bash functions.
   The final gate rejects a moved release tip and uploads
   `release-candidate-X.Y.Z`, recording commit/tree, issue and run/attempt.
6. Only then does `prepare_deployment_action` open Copilot's normal production
   promotion PR. Complete its protected checks/review process. Do not change
   the frozen source after promotion has been recorded.

Reconcile production fixes into development before cutting a candidate.
Publication rejects a production merge whose Git tree differs from the tested
candidate, preventing untested changes from entering through the production base.

## Artifact storage and handoff

Deployment preparation generates every publishable Web artifact and precompiled
CLI library from the reviewed source. It also updates release metadata before
the build chain. Local development outputs and earlier CI builds are not used
as publication inputs.

| Output | Producer in `release_workflow.yml` | Retained location |
|---|---|---|
| Versions, release changelogs, Apple package metadata and CLI version | `update_files` | Committed release candidate |
| `zstd.js`, `zstd_core.js`, `zstd_worker.js`, `zstd.wasm` and matching example copies | `update_files`, through the pinned Emscripten helper | `zstandard_web/blob/` and the example Web directories in the candidate |
| Universal macOS library (x86_64 and arm64) | `cli_build_macos_precompiled_libs` | `zstandard_cli/lib/src/bin/libzstandard_macos.dylib` |
| Linux x64 and arm64 libraries | `cli_build_linux_precompiled_libs` | `zstandard_cli/lib/src/bin/libzstandard_linux_x64.so` and `libzstandard_linux_arm64.so` |
| Windows x64 and ARM64 libraries | `cli_build_windows_precompiled_libs` | `zstandard_cli/lib/src/bin/zstandard_windows_x64.dll` and `zstandard_windows_arm64.dll` |
| Candidate commit/tree and workflow attempt evidence | `ready_to_tag`, after every candidate gate passes | GitHub Actions artifact `release-candidate-X.Y.Z`, retained for 90 days |

The handoff is the committed Git tree, not a runner cache or a temporary build
directory. The Windows job's final commit includes the earlier metadata,
WebAssembly, macOS and Linux outputs. All candidate gates check out that same
commit. The receipt records its identity; it is not an archive of the binaries.
The accepted production commit must have identical content, and the publisher
checks out that production commit without rebuilding the libraries or WebAssembly.

Flutter platform packages distribute the reviewed native source; consumer app
builds compile it for their target. The CLI distributes the precompiled
libraries above, and Web uses the generated WebAssembly assets. Candidate APKs,
desktop applications and test hosts are validation outputs, not pub.dev package
releases.

## Publish and reconcile

After promotion merges, Copilot's installed continuation dispatches `publish`
mode with its durable operation ID. Copilot creates/verifies `vX.Y.Z` at the
accepted production SHA. That immutable tag starts **Publish Tagged Release**;
the issue remains in publication until the package workflow finishes.

Before requesting pub.dev credentials, the tag workflow verifies:

- tag identity, candidate ancestry and production acceptance;
- the exact promotion PR and its unique Copilot operation marker;
- the issue's durable source SHA, production SHA and publication phase;
- a successful preparation run and its unexpired artifact for the exact
  candidate, issue and workflow attempt; and
- identical tested/production trees, metadata and synchronized artifacts.

The `pub.dev` environment requires maintainer approval. Publication begins only
after every platform build and candidate gate has passed and production
promotion has been accepted. OIDC publishing then proceeds in dependency order:

```text
zstandard_platform_interface → zstandard_native
  → zstandard_android → zstandard_ios → zstandard_linux
  → zstandard_macos → zstandard_web → zstandard_windows
  → zstandard_cli → zstandard
```

Each unpublished package must pass `dart pub publish --dry-run`, and the
workflow waits for indexing between packages. Each package receives a fresh
OIDC credential after the preceding indexing wait; a token issued once for the
whole sequence can expire before later uploads. Dependency resolution uses
`pub get --no-example`, so publication checks the distributable package without
resolving example applications that intentionally use local path dependencies.
The Dart SDK matches the version bundled with the tested Flutter SDK.
Only after all ten versions are
independently verified does Copilot create/verify the GitHub Release, receive
the checksum attachment and run `published_deployment_action`. Copilot then
performs its configured protected reconciliation. The old independent
**Integrate Published Release** workflow is retired.

The package uploads are sequential, not an atomic ten-package transaction.
Their order is a dependency requirement, not a trigger to publish each platform
as soon as it compiles. Recovery skips already published immutable versions and
continues the remaining packages for the same accepted candidate and tag.

## Recovery and hotfix compatibility

Before a candidate is frozen, fix the managed branch and rerun preparation.
After promotion is recorded, use Copilot's control center and recovery actions.
Publication recovery retries a failed workflow for the existing tag without
moving it. The tag workflow can also be rerun directly after inspecting the
failure. Published versions are skipped; reconciliation starts only after all
ten packages are verified.

Rerunning a tag workflow uses that tag's original workflow code. An environment
or transient registry failure can be corrected and retried, but a defect in the
frozen publisher requires a corrected new release/version. Keep existing tags
and already published versions unchanged, record the old release as partial,
and obtain authorization for the next patch. Before preparing its candidate,
retain accepted production fixes through Copilot's supported synchronization
command in the new release issue, for example
`/copilot sync-branch --from master --no-agent`. The command must pass the
configured verification, with Flutter available in its own job; a separate
platform CI run does not provision that job. Do not synchronize managed remote
branches manually or mark a partial operation as published.

Evidence is retained for 90 days. Missing, expired or mismatched evidence
blocks publication and cannot be replaced by an operator assertion. Prepare a
new candidate/version when an old frozen operation cannot be verified.
Incorrect published content requires a new version; never overwrite pub.dev.

The installed hotfix workflow is unchanged. Accepted hotfix tags retain its
GitHub-only contract and do not enter the package publisher. A GitHub hotfix
Release is not evidence of ten-package publication.

See the [deployment runbook](../deployment/RUNBOOK.md) and [CI/CD](ci-cd.md).
