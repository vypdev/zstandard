# Self-hosted CI contract

Copilot command verification prepares its project SDK in its own Action job;
platform job setup does not carry over. See
[project dependency setup and activation](project-verification.md).

The repository uses self-hosted runners for platform checks that cannot run reliably on a generic hosted image. The automated scope covers Android, Linux, Web, Apple Silicon macOS/iOS, and Windows X64. Apple and Windows require their corresponding hardware and toolchain.

## Linux runner labels

Linux platform checks and deployment jobs use:

```yaml
runs-on:
  group: vypdev
  labels: [self-hosted, codex, Linux]
```

The runner must be Debian/Ubuntu-based with APT/dpkg tools and network access.
Each job prepares its dependencies through
[`.github/actions/setup-linux-dependencies/action.yml`](../../.github/actions/setup-linux-dependencies/action.yml).
Installed tools are reused; missing packages and their dependencies are
downloaded and extracted into a private job prefix. The action runs no package
maintainer scripts, host package installation or repair, and requires no
passwordless `sudo`. Private paths overlay installed headers and libraries
without changing the host package database.

The expected baseline is:

- Flutter 3.47.2, provisioned or reused in the runner's versioned tool cache by
  [`.github/actions/setup-flutter/action.yml`](../../.github/actions/setup-flutter/action.yml).
  Unix jobs use a private Flutter settings profile and an explicit pub-cache
  location, so concurrent dependency-manager selections remain job-local.
- `build-essential`, Clang, CMake, Ninja, `pkg-config`, and `curl`.
- GTK 3 development headers and Xvfb for Linux/Web desktop jobs.
- Dart's coverage formatter; thresholds are evaluated by
  `scripts/check_lcov_coverage.dart` without host-specific LCOV tooling.

## Android job requirements

In addition to the common Linux baseline, Android jobs require the emulator runtime libraries installed by the shared Linux action (`android: 'true'`), including X11, XCB, OpenGL, NSS, PulseAudio, and D-Bus libraries:

- Android SDK root exposed as `ANDROID_SDK_ROOT` or `ANDROID_HOME`.
- An Android SDK location with writable command-line tools and `platform-tools/adb`. The workflow bootstraps the command-line tools and platform tools when the runner image does not already provide them.
- Java 17.
- KVM is useful for accelerating the x86_64 API 30 emulator, but is not required by the current workflow because the runner does not expose `/dev/kvm`; the workflow explicitly uses software emulation.

The workflow also calls [`scripts/check_android_ci_prerequisites.sh`](../../scripts/check_android_ci_prerequisites.sh), which discovers SDKs in the standard Linux locations when the environment variable is missing. A runner should still export `ANDROID_SDK_ROOT` explicitly so all Android tooling uses the same installation.

The workflow first bootstraps the Android SDK tools, then builds debug APKs for every supported Flutter ABI, starts an API 30 `aosp_atd` `pixel_2` emulator through `scripts/run_android_emulator_ci.sh`, waits for the Android `package`, `input`, and `settings` services to remain stable across repeated checks, and runs the compression, property, and native instrumentation suites. The Android Test Device image is intentionally used for headless testing because these package tests do not require Google Play services. GPS is disabled in the generated AVD because location is outside this test scope, and the launcher disables the emulator's `GnssGrpcV1` feature so it does not start an unnecessary host GNSS socket. Vulkan is disabled explicitly because this runner uses software rendering and the Vulkan/SwiftShader path has crashed during emulator startup. A missing SDK or platform tools fails before the test starts with a diagnostic message. Software emulation is slower than KVM and is given a longer job/boot timeout. The launcher does not run optional input or animation setup commands before the Android system services are ready, and each ADB operation is bounded by a timeout to prevent an offline daemon from hanging the job; if boot or readiness fails, it prints the emulator log and Android logcat for diagnosis.

The launcher also initializes and exports `ANDROID_USER_HOME` and
`ANDROID_AVD_HOME` explicitly. This is required on clean hosted images where
`avdmanager` does not create the default `$HOME/.android/avd` hierarchy before
returning.

The Android matrix runs sequentially because all entries share the runner's ADB daemon and emulator port. It covers both example projects and both native-source layouts: the normal workspace path and an exact external path recorded in Dart's package configuration.

After JDK setup,
[`prepare-android-gradle`](../../.github/actions/prepare-android-gradle/action.yml)
selects the job's Java 17 in its private Flutter settings and creates a private
`GRADLE_USER_HOME`. The deployment candidate job also separates the modern and
legacy consumers' Gradle state. The operator's Gradle cache is preserved.

## Linux job requirements

The workflow builds `zstandard_linux/example` with `flutter build linux --debug`, runs native CTest coverage, executes package tests with the built plugin on `LD_LIBRARY_PATH`, and executes the desktop integration suite under Xvfb. The sequence is repeated with the current `zstandard_native` package staged outside the checkout and selected through `package_config.json`, proving that CMake does not rely on the monorepo-relative fallback.

## Apple job requirements

iOS and macOS jobs use group `vypdev` and labels
`[self-hosted, macOS, ARM64]`. The setup action installs or reuses the pinned
Flutter SDK in that runner's versioned tool cache. Each runner process must
execute one job at a time.
Do not add a shared job-level Actions concurrency group to the iOS and macOS
matrices: GitHub retains only one pending job per group and cancels the other
matrix combinations instead of queuing them. Matrix `max-parallel: 1` provides
per-workflow serialization, while the runner process serializes work across
the two workflows.

SwiftPM/CocoaPods selection uses the job's private Flutter settings profile.
iOS integration and deployment-candidate jobs use a disposable SDK copy with
the reviewed simulator log-readiness backport, then remove only their own
marked directory. The shared SDK stays unchanged; see the
[backport provenance](../../.github/patches/README.md).

## Windows job requirements

Windows jobs target `[self-hosted, Windows, X64]`. The workflow installs and caches the pinned Flutter SDK on each runner, enables Windows desktop support, verifies Git and CMake, and checks that the runner can create symbolic links. The runner must provide a Visual Studio C++ desktop toolchain and Windows Developer Mode (or equivalent `SeCreateSymbolicLinkPrivilege` for the runner service account). Integration tests launch a real Windows Flutter application, so the runner must have an interactive desktop session; a headless service session is not sufficient for this job.

Windows CI and release jobs use the built-in Windows PowerShell (`powershell`), including runners without PowerShell 7 (`pwsh`). Release preparation selects a Visual Studio instance with both x64 and ARM64 tools, passes that exact instance to CMake and writes GitHub output files explicitly as UTF-8; Windows PowerShell 5.1 otherwise redirects output as UTF-16. The CLI library producer uses GitHub's standard `windows-2025` image, which includes both toolsets; Windows application integration stays on the self-hosted desktop runners described here.

Windows setup resolves CMake and CTest from the job's current `PATH`, a standalone CMake installation, or Visual Studio's bundled CMake tools, then adds their directory to the job's `PATH`. A machine-wide `PATH` change is not required; both executables must be installed and runnable.

The workflow builds `zstandard_windows/example` in Debug mode, runs the generated native test target (including a zstd compression/decompression round trip), runs the Windows package tests with the built DLL on `PATH`, and launches the example for Flutter integration tests. The same sequence is repeated with the current `zstandard_native` package staged outside the checkout and selected through `package_config.json`. A separate federated-example job builds `zstandard/example` and runs its integration suite.

## Web job requirements

Flutter 3.47.2 does not support running `package:integration_test` directly with `flutter test -d chrome`. The workflow therefore uses the supported WebDriver path:

1. Install Chrome for Testing and its matching ChromeDriver with `browser-actions/setup-chrome@v2`.
2. Build the example with `flutter build web --release`.
3. Start ChromeDriver on port 4444 and verify its `/status` endpoint.
4. Run `flutter drive` against `-d web-server` under Xvfb.

The workflow fails if ChromeDriver cannot be installed, started, or used. There is no silent fallback to a passing-but-untested Web job.

## What each push check proves

- Analyze jobs prove dependency resolution and static analysis with the repository Flutter version.
- Build steps prove that the platform project and native/WASM integration compile.
- Android, Linux, and Web integration tests execute the real platform implementation and its compression/decompression round trips.
- Package-config rows prove that native build systems consume the exact resolved package path instead of accidentally relying on a sibling checkout directory.
- Coverage and publish dry runs remain package-level quality gates.

These CI builds produce disposable validation hosts. Publishable WebAssembly
and precompiled CLI libraries are regenerated by the Copilot deployment
workflow and retained in its tested candidate. See
[artifact storage and handoff](release-process.md#artifact-storage-and-handoff).

## Android sessions on shared Linux hosts

Several runner services on one Linux machine share the Android SDK and ADB
daemon. The Android launcher leases the whole SDK/emulator/test session through
a private, user-scoped host lock, including cleanup. A workflow's matrix limit
alone cannot coordinate another PR or release workflow. Waiting for this lease
is bounded by `ANDROID_CI_LOCK_TIMEOUT_SECONDS` (3600 seconds by default).
Android PR test jobs allow 120 minutes for provisioning, waiting and tests.

By default, each session uses a job-local AVD home and a unique AVD name. The launcher
exports the selected `ANDROID_SERIAL`, refuses an already active device on its
port and terminates only the emulator process it started. It never kills an
existing device just to make room. The lease stays in a parent process, so an
ADB daemon cannot retain it; cancellation is forwarded to the worker and its
cleanup finishes before the lease is released.

## Complete history for deployment checkouts

Release preparation and tag validation use the project-owned
`checkout-release-source` composite. GitHub's [checkout-free local Action
syntax](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/find-and-customize-actions)
(`$/`) loads it from the workflow's exact revision before the workspace checkout.
External Actions still use version tags.

An inherited shallow checkout can fail a full-history fetch with
`pack has unresolved deltas`, even after checkout's built-in retries. Before
fetching release history, the composite verifies the runner workspace hierarchy,
repository identity and clean source state. It moves only shallow Git metadata
to private job temporary storage, retaining the old cache for that job, and lets
the official checkout action fetch a new complete repository. It leaves complete
checkouts alone and refuses linked worktrees, locks, stashes, unexpected files
or local branches absent from cached remote refs. It does not modify the runner's
global Git configuration or any remote branch or tag. The runner's normal job
temporary-directory cleanup retires the cached metadata.

Apple validation jobs save the tracked Xcode project and scheme files before
Flutter runs and restore their exact starting contents in an `always()` step
after integration tests. Flutter's SwiftPM migrations are test-host changes;
leaving them in a shared checkout can block the next release's clean-source
check. If an older job left those migrations behind, run the corrected Apple
PR checks before preparing again. Their ordinary checkout and final restoration
clean the CI host without weakening the deployment checkout's source guards.
