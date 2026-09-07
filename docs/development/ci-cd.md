# CI/CD

## Pull requests

`pull_request.yml` is the untrusted-code safety gate. It runs on GitHub-hosted
Ubuntu with read-only contents permission, resolves monorepo dependencies,
formats and analyzes all ten packages, executes every available VM/unit test,
and validates metadata, generated Web artifacts, and shell syntax. A required
hosted matrix collects coverage for the CLI, platform interface, and main
package on every pull-request head, enforces their package-specific thresholds,
and uploads the three matching Codecov flags for trusted same-repository pull
requests. Forks run the same coverage gates without receiving the upload token.
Its final
`Pull Request Safety Gate` job is the stable required-check context; repository
rules should require that one context on both `master` and `develop` rather
than coupling protection to individual matrix-entry names.

Untrusted pull-request code is never sent to persistent self-hosted runners.
The platform-heavy workflows (`pr_check_*.yml`, retained under their historic
names) run only on trusted pushes to `develop` or by explicit manual dispatch.
They provide Android emulator/instrumentation, Linux desktop, ChromeDriver,
Windows desktop/native, and both SwiftPM and CocoaPods Apple integration. They
also run publish dry-runs and coverage where applicable.

Every third-party action reference is pinned to a full commit SHA. Copilot
automation uses `pull_request_target` or issue metadata without checking out
untrusted pull-request code, grants read-only repository contents, and only
uses its PAT for OWNER, MEMBER, or COLLABORATOR actors.

## Release workflows

- `release_workflow.yml` (**Task - Prepare Release**) runs only by manual
  dispatch on `release/X.Y.Z`. It mutates the release branch, builds native
  artifacts, and validates the complete candidate. It neither tags nor
  publishes.
- `publish_workflow.yml` (**Publish Tagged Release**) runs only for a stable
  `vX.Y.Z` tag, validates that it points to the matching release-branch tip,
  publishes all packages with OIDC on GitHub-hosted Ubuntu, verifies pub.dev,
  and creates the GitHub release.
- `integrate_release.yml` (**Integrate Published Release**) is a separate
  manual workflow. It verifies the completed publication and opens reviewed
  pull requests into `master` and `develop`; it never merges or bypasses
  branch protection.

Both workflows share one non-cancelling concurrency group, preventing two
publication state machines from overlapping.

## Runner trust and requirements

Self-hosted Linux, Windows, and macOS runners are persistent trusted release
infrastructure. They must not be exposed to fork pull requests. Linux needs
the native/GTK toolchain, Android SDK/Java 17, Chrome, and optional AArch64
cross-tools. Windows needs Visual Studio C++/CMake and an interactive desktop.
Apple needs Xcode, simulator runtimes, CocoaPods, and a logged-in WindowServer
session for macOS integration.

The local composite actions verify the pinned Flutter 3.47.2 toolchain.
Platform workflows build release candidates as well as debug test hosts;
missing infrastructure is a failure rather than a silent skip.

## Local equivalents

Use `dart scripts/create_local_overrides.dart <package>` before resolving an
individual monorepo package; the `.sh` wrapper remains available on Unix-like
systems. Run `dart format --output=none
--set-exit-if-changed .`, the appropriate analyzer/test command, and the
platform integration script. `scripts/check_pub_metadata.dart` validates the
publication contract; `scripts/build_web_wasm.sh` regenerates Web artifacts.

See [Testing](testing.md), [Self-hosted CI](self-hosted-ci.md), and
[Release process](release-process.md).
