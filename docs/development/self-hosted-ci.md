# Self-hosted CI contract

The repository uses self-hosted runners for platform checks that cannot run reliably on a generic hosted image. The automated scope covers Android, Linux, Web, Apple Silicon macOS/iOS, and Windows X64. Apple and Windows require their corresponding hardware and toolchain.

## Linux runner labels

The automated non-Apple checks use:

```yaml
runs-on: [self-hosted, Linux]
```

The runner must be Debian/Ubuntu-based and allow the runner account to use passwordless `sudo`. Each job installs and verifies its common toolchain through [`.github/actions/setup-linux-dependencies/action.yml`](../../.github/actions/setup-linux-dependencies/action.yml), so the runner image does not need a manually maintained copy of CMake or GTK.

The expected baseline is:

- Flutter 3.47.2, selected explicitly by the workflows through [`.github/actions/setup-flutter/action.yml`](../../.github/actions/setup-flutter/action.yml). The action also marks the shared Flutter checkout as a Git safe directory, which is required by the self-hosted runner image.
- `build-essential`, Clang, CMake, Ninja, `pkg-config`, and `curl`.
- GTK 3 development headers and Xvfb for Linux/Web desktop jobs.
- `lcov` and `bc` for coverage jobs.

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

## Linux job requirements

The workflow builds `zstandard_linux/example` with `flutter build linux --debug`, runs native CTest coverage, executes package tests with the built plugin on `LD_LIBRARY_PATH`, and executes the desktop integration suite under Xvfb. The sequence is repeated with the current `zstandard_native` package staged outside the checkout and selected through `package_config.json`, proving that CMake does not rely on the monorepo-relative fallback.

## Apple job requirements

iOS and macOS jobs target `[self-hosted, macOS, ARM64]` and use the pinned,
preinstalled Flutter SDK. Each runner process must execute one job at a time.
Do not add a shared job-level Actions concurrency group to the iOS and macOS
matrices: GitHub retains only one pending job per group and cancels the other
matrix combinations instead of queuing them. Matrix `max-parallel: 1` provides
per-workflow serialization, while the runner process serializes work across
the two workflows.

## Windows job requirements

Windows jobs target `[self-hosted, Windows, X64]`. The workflow installs and caches the pinned Flutter SDK on each runner, enables Windows desktop support, verifies Git and CMake, and checks that the runner can create symbolic links. The runner must provide a Visual Studio C++ desktop toolchain and Windows Developer Mode (or equivalent `SeCreateSymbolicLinkPrivilege` for the runner service account). Integration tests launch a real Windows Flutter application, so the runner must have an interactive desktop session; a headless service session is not sufficient for this job.

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
