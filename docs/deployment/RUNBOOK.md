# Deployment and Recovery Runbook

## One-time configuration

1. Configure automated publishing on pub.dev for all ten packages, this GitHub
   repository, and stable `vX.Y.Z` tags.
2. Create and protect the GitHub `pub.dev` environment. Require a reviewer if
   that matches the project's release policy.
3. Protect stable tags and release/development branches. Keep self-hosted
   platform workflows restricted to trusted pushes or manual dispatch.
4. Allow GitHub Actions to create pull requests. After the integration
   workflow opens them, a maintainer must approve the resulting safety-gate
   runs, which GitHub initially places in an approval-required state.

No `dart pub login` credential or persistent pub token is required. The tagged
workflow exchanges GitHub's short-lived OIDC identity for publication access.

## Prepare a release

1. Create `release/X.Y.Z` and update the root changelog.
2. Push the branch and run **Task - Prepare Release** on that exact branch.
3. Enter version `X.Y.Z` without `v`; complete the title/changelog inputs.
4. Wait for all native-library builds, release builds, integration tests, and
   metadata checks.
5. Review the workflow summary and record the reported candidate SHA.

The workflow commits its generated versions and native artifacts to the
release branch. It refuses an existing stable tag, so there is no resume mode
that can bypass candidate validation.

## Publish

After approval, create `vX.Y.Z` at the exact remote branch tip and push it:

```bash
git fetch origin release/X.Y.Z
test "$(git rev-parse origin/release/X.Y.Z)" = "EXPECTED_CANDIDATE_SHA"
git tag -s vX.Y.Z EXPECTED_CANDIDATE_SHA
git push origin vX.Y.Z
```

**Publish Tagged Release** independently rechecks the tag/branch identity,
metadata, five CLI native libraries, and four synchronized Web artifacts. It
then publishes sequentially in dependency order, waits for public indexing,
runs a publication dry-run immediately before each unpublished package,
verifies all ten versions, and creates the GitHub release with checksums.

## Recovery

- Preparation failure: fix the release branch and rerun preparation. No tag or
  package has been published.
- Publication job interrupted: rerun the same tag workflow. The helper skips
  a package version only after pub.dev reports it publicly, then continues in
  dependency order.
- Dependency not indexed: the workflow waits up to 20 minutes per package. If
  pub.dev remains unavailable, rerun later with the same immutable tag.
- Incorrect tagged content: never move or recreate the tag and never attempt
  to overwrite a pub.dev version. Prepare a new patch release.
- GitHub release failure after all packages publish: rerun the workflow; its
  release creation/upload is idempotent.

After publication, run **Integrate Published Release** with the same version.
It revalidates the final release and opens or reuses pull requests from the
release branch into `master` and `develop`. Review and merge both normally;
the workflow does not merge or bypass branch protection. Do not delete the
release branch until both pull requests are complete.

## Updating upstream zstd

`scripts/update_zstd.sh` defaults to the repository's pinned upstream commit;
an explicit tag or commit can be passed for an intentional upgrade. Review the
diff, update `zstandard_native/UPSTREAM_ZSTD.md`, regenerate bindings when the
public header changes, regenerate WebAssembly, and rerun every platform gate.
Apple CocoaPods sync scripts create ignored compatibility copies; SwiftPM uses
the canonical repository target directly.

See [Release process](../development/release-process.md) and
[`SECURITY.md`](../../SECURITY.md).
