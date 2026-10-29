# CI/CD

## Pull requests

`pull_request.yml` supplies the required safety gate for same-repository pull
requests. Its jobs use runner group `vypdev` with labels
`[self-hosted, codex, Linux]` and read-only repository contents permission.
They resolve monorepo dependencies, format and analyze all ten packages, run
package unit tests, and validate metadata, generated Web artifacts and shell
syntax. The required coverage matrix checks the CLI, platform interface and
main package, enforces their individual thresholds, and uploads matching
Codecov flags for eligible same-repository actors. Its final
`Pull Request Safety Gate` job is the stable required-check context; repository
rules should require that one context on both `master` and `develop` rather
than coupling protection to individual matrix-entry names.

Fork pull requests are excluded by the same-repository job conditions,
including the final safety gate; this workflow supplies no executed test or
coverage evidence for a fork head. Fork changes need review and validation on
a trusted same-repository branch before inclusion in a release.

The platform-heavy workflows (`pr_check_*.yml`, retained under their historic
names) run on same-repository pull requests and pushes to `develop`. Their
job conditions exclude fork pull requests from persistent runners.
They provide Android emulator/instrumentation, Linux desktop, ChromeDriver,
Windows desktop/native, and both SwiftPM and CocoaPods Apple integration. They
also run publish dry-runs and coverage where applicable.

`android_windows_sources.yml` separately verifies Android source discovery on
a Windows host with both packages staged in a versioned cache outside the
consumer and builds ARM64 native code. Android execution coverage remains in
the Linux emulator matrix. See the [Windows Android runner
contract](self-hosted-ci.md#android-builds-hosted-on-windows).

Actions in workflows and composite actions must use version tags such as
`@v1`, `@v2` or `@v3`. Commit SHA references are not permitted. The package
preparation contract checks this policy when workflow or action files change.
Copilot automation uses `pull_request_target` or issue metadata without checking out
untrusted pull-request code, grants read-only repository contents, and only
uses its PAT for OWNER, MEMBER, or COLLABORATOR actors.

The installed approval observer evaluates the current revision using
`PR_APPROVAL_POLICY`. Its current `recommend` policy observes `Analyze Zstandard`,
`Test Zstandard` and the coverage evidence supplied by `Test Zstandard`; a
recommendation is distinct from a maintainer's approval. Effective branch rules
must be readable and dismiss stale approvals on new pushes. Keep these observed
package checks when validating a documentation-only PR, even if redundant
platform runs are cancelled. After correcting a prerequisite, use the existing
[approval observer](../../.github/workflows/copilot_pull_request_approval.yml)
with the PR number to refresh its assessment. This does not launch deployment.

## Release workflows

`release_workflow.yml` retains Copilot's `prepare`, `publish` and `resume`
contract. Preparation consumes an admitted managed release branch, generates
metadata/native artifacts and runs all candidate gates on one exact commit.
It uploads a commit/tree receipt and invokes Copilot's production promotion.
After protected promotion, Copilot's publication continuation creates/verifies
the accepted production tag. Failed tag publications are retried without
moving that tag.

All publishable release metadata, WebAssembly and precompiled CLI libraries
are produced by deployment preparation. The native build jobs run in order
(macOS, Linux, Windows), committing their outputs to the managed release
branch and passing the resulting commit to the next job. Candidate validation
starts after the complete set exists. Publication consumes the accepted
production commit with the same tested Git tree; it does not publish packages
as individual platform builds finish. See
[artifact storage and handoff](release-process.md#artifact-storage-and-handoff).

`publish_workflow.yml` runs only on stable version tag pushes. Before OIDC it
requires a successful candidate run/attempt, its artifact, identical tested and
production content, and the matching Copilot promotion/issue state. The
protected `pub.dev` environment requires maintainer approval. After publishing
and independently verifying all ten packages, the installed Copilot actions
create/verify the GitHub Release and start configured reconciliation. Accepted
hotfixes preserve their existing GitHub-only lane.

Copilot state transitions share its per-issue non-cancelling queue. Package
publication has a separate repository-wide lock, so waiting for environment
approval cannot deadlock a Copilot continuation. The former standalone
integration workflow is retired; Copilot owns reconciliation and cleanup.

The package preparation contract runs real version/metadata helpers, actual
CMake path resolution, Git commit/retry scenarios, admission scripts and
candidate evidence validation using isolated fixtures. These tests never call
a publication API. See [Release process](release-process.md).

## Runner trust and requirements

Self-hosted Linux, Windows, and macOS runners are persistent trusted release
infrastructure. They must not be exposed to fork pull requests. Linux needs
the native/GTK toolchain, Android SDK/Java 17, Chrome, and optional AArch64
cross-tools. Windows needs Visual Studio C++/CMake and an interactive desktop.
Apple needs Xcode, simulator runtimes, CocoaPods, and a logged-in WindowServer
session for macOS integration.

The local composite actions provision and verify the pinned Flutter 3.47.2
toolchain in each runner's versioned tool cache. Ordinary platform CI builds
disposable example/test hosts, including release-mode builds where required.
Those outputs validate changes; the deployment workflow builds the artifacts
that will be published. Missing infrastructure is a failure rather than a
silent skip.

## Local equivalents

Use `dart scripts/create_local_overrides.dart <package>` before resolving an
individual monorepo package; the `.sh` wrapper remains available on Unix-like
systems. Run `dart format --output=none
--set-exit-if-changed .`, the appropriate analyzer/test command, and the
platform integration script. `scripts/check_pub_metadata.dart` validates the
publication contract. `scripts/build_web_wasm.sh` is the deployment helper for
regenerating Web artifacts; running local development commands does not
prepare or authorize a release.

See [Testing](testing.md), [Self-hosted CI](self-hosted-ci.md), and
[Release process](release-process.md).

### Self-hosted Linux runner contract

Linux workflows use runner group `vypdev` with labels
`[self-hosted, codex, Linux]`. The Debian/Ubuntu runner provides APT/dpkg tools
and network access. The
[Linux dependency action](../../.github/actions/setup-linux-dependencies/action.yml)
reuses installed dependencies and downloads missing packages and their
dependency closure into a private job prefix. It extracts packages without
running maintainer scripts or changing the host package database. It requires
no passwordless `sudo` and performs no host package repair.

The common toolchain includes `build-essential`, Clang, CMake, Ninja,
`pkg-config`, and `curl`. Desktop jobs select GTK and Xvfb; coverage jobs select
`lcov` and `bc`; browser jobs select Chrome's runtime libraries. Private headers
and libraries are combined with read-only links to the installed toolchain.

The release workflow enables the action's `arm64` option for the
`aarch64-linux-gnu` cross compiler before building the Linux ARM64 CLI library.
Android jobs avoid exporting host development-header search paths into the
NDK build; the ARM64 cross-build similarly clears host paths that would
override its sysroot.

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

The Windows workflow builds and tests the implementation package from the repository and from the exact candidate in a private Pub-cache-shaped tree. Each path runs the native C++ zstd round-trip tests, Dart package tests, and launched Flutter integration tests. A separate job runs the federated `zstandard/example` application to verify the public plugin entry point on Windows.


## Unpublished API candidates

The integrity audit adds `ZstandardNativeCodec` and bounded decompression to
packages whose current published 1.5.0 versions do not contain those APIs.
All PR jobs resolve matched monorepo dependencies through the reviewed
`prepare-candidate-dependencies` action. Native matrices retain workspace
and `pub-cache` source layouts: the latter copies only tracked candidate
files into a job-private `hosted/pub.dev/zstandard_native-<version>` tree and
a separate Swift package root, then hides the workspace native package.
This tests discovery outside the checkout; it is not evidence of a new
pub.dev publication. The interface and platform dependencies remain matched
to the candidate through generated local overrides. Originals are restored
from this job's private backup after native checks.

Seven filesystem regression tests cover 14 distinct inputs: workspace and
private-cache success, four invalid source values, missing CI output, five
malformed versions, tracked source drift and an escaping tracked symlink.
They exercise the actual Dart staging helper. The platform matrices continue
to build and launch their real native hosts; these fixtures replace none of
those checks. Release preparation updates all package versions and minimum
inter-package dependencies together before any immutable tag or publication.
