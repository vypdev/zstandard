# Deployment and Recovery Runbook

## Release readiness without publication

1. Verify all ten packages' pub.dev Admin settings: repository
   `vypdev/zstandard`, tag pattern `v{{version}}`, required environment `pub.dev`.
   An uploader or publisher admin must verify these private settings.
2. Verify `pub.dev` has a maintainer reviewer and only the `v*` tag policy.
3. Verify active `master`/`develop` protection requires `Pull Request Safety
   Gate` and prevents deletion/non-fast-forward updates. Keep merge commits and
   Copilot's managed branch lifecycle available.
4. Verify stable tags cannot change or be deleted, installed Copilot credentials
   are healthy, and trusted Linux/macOS/Windows runners are online.
5. Run release contract tests, metadata checks and PR platform CI. No tag or
   registry credential is needed for these checks.
6. Record the release type and SDK compatibility in the Release issue. For a
   patch, select `Patch` and `Automatic`; from `v1.5.1`, Copilot resolves `1.5.2`.
   Announce Dart 3.12 / Flutter 3.44 minimums in the release notes. Maintenance
   changes alone do not authorize deployment.

Do not add `deploy`, create tags/releases or run publication to test readiness.
Publishing to pub.dev is immutable and is not a readiness test.

## Authorized release

Use the installed Release form, add `in-progress` as a maintainer and wait for
Copilot's linked branch and readiness label. Once deployment is explicitly
authorized, its launcher starts preparation. Follow the issue's control center
through candidate validation and the production promotion PR.

All publishable generation and compilation belongs to the deployment's
`prepare` phase. Do not prepare package versions, WebAssembly or CLI libraries
on a developer machine for later upload. The workflow generates metadata and
Web assets, then compiles and commits macOS, Linux and Windows libraries in
sequence. Each job consumes the preceding commit; the complete set is retained
in the final candidate's Git tree before candidate validation or publication.
See the [artifact map](../development/release-process.md#artifact-storage-and-handoff).

All platform jobs validate one exact candidate. Its commit/tree evidence is
uploaded before promotion is delegated to Copilot. After the protected PR
merges, Copilot tags the accepted production SHA. Do not manually tag the
release tip: production and candidate commits can differ while their tested
content must be identical.

CI and candidate example-app builds remain validation hosts. Flutter platform
packages ship native source; the distributed precompiled libraries belong to
the CLI, and the generated Web assets belong to the Web implementation.

The tag publisher verifies Copilot state, promotion ownership, successful CI
evidence and metadata before reaching the protected `pub.dev` environment.
Approve that environment after reviewing the accepted candidate. Publication
uses GitHub OIDC; no persistent pub token is required.

No platform is published during the native build chain. Once all builds and
candidate gates pass, the ten package uploads run in dependency order and wait
for indexing. Each package renews its OIDC credential after the previous wait.
Resolve only the distributable package with `pub get --no-example`; example
apps remain covered by candidate/CI tests. This is not an atomic registry transaction: if publication stops,
use Copilot recovery for the same accepted candidate/tag to continue missing
versions, rather than rebuilding and uploading platforms independently.

After public verification of all ten packages, the product workflow delegates
GitHub Release creation and reconciliation to installed Copilot actions. Do not
create independent integration PRs or delete managed branches yourself.

## Recovery

- Preparation failure before promotion: fix the linked branch and start a new
  preparation through Copilot's authorized launcher when workflow code changed.
  GitHub reruns retain the original workflow revision; they suit transient
  failures with unchanged code. Native commit steps accept unchanged outputs.
- Checkout reports `pack has unresolved deltas`: deployment checkouts retire
  inherited shallow Git metadata in the verified runner workspace before a fresh
  full-history fetch. Inspect a refusal rather than deleting worktrees, stashes,
  authored changes or another checkout. See
  [complete-history checkout](../development/self-hosted-ci.md#complete-history-for-deployment-checkouts).
- Remote tip moved: preparation stops rather than silently testing a newer
  commit. Inspect the concurrent change and start a consistent candidate attempt.
- Promotion-PR CI requires a source correction before acceptance: Copilot has
  already frozen the candidate SHA. Disable that PR's auto-merge and use an
  explicitly approved recovery for the unpublished candidate; the current
  limitation is tracked in [Copilot #732](https://github.com/vypdev/copilot/issues/732).
  A replacement needs a complete new preparation and its own evidence. Never
  reuse the old attestation or rewrite its stored `sourceSha` in place.
- Production content differs: reconcile the production change before preparing
  a new candidate; do not bypass evidence validation.
- Publication interrupted or indexing delayed: inspect the issue failure and
  retry its publication action or the same tag workflow. Already public package
  versions are safely skipped.
- Existing tag on recovery: the continuation retries its failed publication
  workflow, preserving the tag and operation identity.
- Publisher code defect after tagging: a retry runs the same frozen workflow.
  Prepare an authorized new patch with the fix, leaving the old tag and public
  package versions unchanged. Record the old operation's partial publication;
  do not report it as complete. Preserve production fixes in the new candidate
  through Copilot's supported branch synchronization before preparation.
- SDK setup reports a missing `dart-analyzer.json`: the package publisher runs
  the SDK action inside a composite, whose inherited action path contains no
  analyzer matcher. Publication SDK setup disables only that optional matcher
  with `problem-matcher: false`; dry runs and required CI stay enabled. For an
  already tagged workflow, prepare a new patch with this correction.
- Copilot synchronization verification reports `flutter: command not found`:
  provision Flutter for the command's own job, then retry the same supported
  command. Do not remove configured tests or manually merge the managed branch.
- GitHub Release/checksum finalization failed: rerun the same tag workflow.
  Existing packages are reused; Copilot verifies its release receipt.
- Expired evidence: publication stops. Retention is 90 days; plan a new verified
  candidate/version rather than fabricating a replacement attestation.
- Incorrect published content: prepare a new version. Never move a stable tag
  or attempt to overwrite a published package.

Hotfixes retain their existing Copilot GitHub-only publication contract and do
not implicitly publish packages to pub.dev.

## Updating upstream zstd

`scripts/update_zstd.sh` defaults to the pinned upstream commit. For an
intentional upgrade, review the diff, update `zstandard_native/UPSTREAM_ZSTD.md`,
regenerate bindings if the public header changed, regenerate WebAssembly and
rerun every platform gate. Apple CocoaPods sync scripts create ignored
compatibility copies; SwiftPM uses the canonical repository target directly.

See [Release process](../development/release-process.md) and the
[security guide](../guides/security.md).
