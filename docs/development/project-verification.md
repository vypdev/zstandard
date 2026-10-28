# Project dependencies for Copilot verification

Application CI and Copilot commands run in separate jobs. The Flutter setup in
an Android, Linux, Web or Apple build does not prepare the job that handles an
issue comment. A branch synchronization can therefore fail with
`flutter: command not found` even when platform CI is passing.

The repository uses Copilot's supported project dependency hook at
`.github/actions/copilot-verification-setup/action.yml`. This composite belongs
to this project. It provisions Flutter 3.47.2 and its bundled Dart SDK inside
the verification job, reusing the same versioned runner tool cache as normal
CI. Linux compiler/GTK dependencies use the existing rootless private package
bootstrap, shared with platform CI. Reviewed launchers carry native include and
library settings through Copilot's supported PATH handoff. The preparation
does not require global Flutter or package installation in the runner service.
All remote Action references use version tags.

The installed comment workflows already call Copilot's reusable coordinator.
They do not need modification to use this hook. The Copilot engine, approval
policy, configured verification commands, managed branches and deployment
lifecycle remain unchanged.

Ordinary application jobs also isolate Dart's configuration, including commands
that invoke a freshly installed Dart SDK directly. The package archive cache
can be reused, while pub.dev token references stay in the job's private profile.
A publication job must not leave later public dependency reads dependent on its
short-lived `PUB_TOKEN` environment variable.

## Review and activation

1. Keep `VERIFICATION_SETUP=false` while preparing and reviewing the hook.
   Enabling the generated placeholder does not install dependencies; it fails.
2. Run **Project verification setup contract** on the maintenance PR. It installs
   the project hook in the same Linux job as `bash scripts/test_all.sh`, with
   a private dependency profile. The check requires the tests to pass without
   tracked changes or new publishable files. Platform CI remains required.
   The test runner resolves local candidate packages, builds the actual Linux
   example plugin before its FFI unit tests and restores existing local
   dependency overrides after success or failure. These builds are validation
   hosts; distributable generation remains in release preparation.
3. Review and merge the dependency configuration onto trusted `master` before
   enabling `VERIFICATION_SETUP=true`. Copilot reads the trusted main snapshot;
   a change only on a candidate branch cannot replace that setup.
4. Retry the original supported command, such as
   `/copilot sync-branch --from master --no-agent`, and inspect its actual native
   setup and verification steps. Successful product CI validates the project
   hook, while the command run verifies its integration with Copilot isolation.

Copilot provides a fresh private dependency profile for each configured check.
Setup may install dependencies but must leave tracked and publishable source
unchanged. It runs with a five-minute setup deadline and fails closed if setup
or verification fails. Keep configured tests intact and diagnose missing native
test prerequisites through the project CI contract.

To disable the project hook, set `VERIFICATION_SETUP=false`. Future commands
then need their dependencies provisioned in their own job. Disabling the hook
does not alter any accepted candidate, stable tag or published package.

See the primary [Copilot project setup contract](https://github.com/vypdev/copilot/blob/v3/docs/security-operations/operations/verification.mdx#repository-owned-setup).
