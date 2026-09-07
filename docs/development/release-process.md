# Release Process

All ten published packages use one stable `MAJOR.MINOR.PATCH` version. A
release has three deliberately separate stages: candidate preparation,
tag-triggered publication, and reviewed branch integration.

## Candidate checklist

- Update the root changelog with user-facing changes.
- Run format, analysis, tests, native integration tests, metadata checks, and
  `dart pub publish --dry-run` for every package.
- Confirm `zstandard_native/UPSTREAM_ZSTD.md` records the exact upstream zstd
  version, commit, and any backport.
- Confirm all four generated Web files are synchronized across the package and
  examples.
- Confirm the Apple SwiftPM manifests and CocoaPods podspecs build the same
  common/compress/decompress source set.

## Stage 1: prepare and validate

Create and push `release/X.Y.Z`, then run **Task - Prepare Release** from that
branch with version `X.Y.Z`. The workflow refuses existing tags and mismatched
branch/version values. It:

1. updates changelogs, package/dependency versions, podspecs, and exact SwiftPM
   versions;
2. regenerates the pinned Web Worker/WASM artifacts;
3. builds and commits macOS universal, Linux x64/arm64, and Windows x64/arm64
   CLI libraries;
4. runs static, release-build, and native integration candidate gates on the
   trusted platform runners; and
5. reports the exact remote release-branch commit that is ready to tag.

The preparation workflow does not create a tag and cannot publish. Re-run it
only while the release tag does not exist.

## Stage 2: immutable tag and OIDC publication

After reviewing the successful candidate, push `vX.Y.Z` at exactly the commit
reported by the workflow:

```bash
git fetch origin release/X.Y.Z
git tag -s vX.Y.Z origin/release/X.Y.Z
git push origin vX.Y.Z
```

The **Publish Tagged Release** workflow revalidates that the tag equals the
tip of `origin/release/X.Y.Z`, publishes through GitHub OIDC in this order, and
waits for pub.dev indexing between dependency layers:

```text
zstandard_platform_interface
  → zstandard_native
  → zstandard_android → zstandard_ios → zstandard_linux
  → zstandard_macos → zstandard_web → zstandard_windows
  → zstandard_cli
  → zstandard
```

It then verifies all ten public versions and creates an immutable GitHub
release containing checksums for the native and Web artifacts. No dirty source
archives are attached.

Publication is idempotent for a workflow retry: versions already visible on
pub.dev are skipped. Before each unpublished package is sent, its dependencies
are resolved and `dart pub publish --dry-run` must pass. A tag never moves. If
the tagged candidate is wrong, prepare a new patch version.

## Stage 3: reviewed branch integration

After publication succeeds, run **Integrate Published Release** with `X.Y.Z`.
It verifies that the stable tag equals `release/X.Y.Z`, that the GitHub Release
is final, and that all ten versions are visible on pub.dev. It then opens or
reuses pull requests from the release branch into `master` and `develop`.

The workflow never merges a pull request and never bypasses a ruleset. Keep
the release branch until both pull requests have passed their normal review
and required checks and have been merged.

## Required external configuration

For every pub.dev package, configure automated publishing for this GitHub
repository and the stable `vX.Y.Z` tag pattern. Protect the GitHub `pub.dev`
environment with appropriate reviewer rules. The workflow uses
`id-token: write`; no persistent pub token belongs on a runner.

Allow GitHub Actions to create pull requests in the repository Actions
settings. The integration workflow uses only its short-lived `GITHUB_TOKEN`
with contents-read and pull-requests-write permissions. GitHub places checks
triggered by an automation-created pull request in an approval-required state;
a maintainer must approve those runs from the pull request before merging.

Protect `master`, `develop`, release branches, and stable tags with active
GitHub rulesets. Require pull requests and the stable `Pull Request Safety
Gate` status context on both long-lived branches, plus deletion and
non-fast-forward protection. Remove obsolete per-matrix context names before
enabling a ruleset. The integration workflow only opens reviewed pull
requests; it cannot merge or bypass those protections.

See the [deployment runbook](../deployment/RUNBOOK.md) and
[CI/CD](ci-cd.md).
