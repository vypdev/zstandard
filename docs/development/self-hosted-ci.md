# Self-hosted CI contract

The repository uses self-hosted runners for platform checks that cannot run reliably on a generic hosted image. The current automated scope is Android, Linux, and Web. Apple and Windows remain separate platform workflows and require their corresponding hardware and toolchain.

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
- KVM is useful for accelerating the x86_64 API 31 emulator, but is not required by the current workflow because the runner does not expose `/dev/kvm`; the workflow explicitly uses software emulation.

The workflow also calls [`scripts/check_android_ci_prerequisites.sh`](../../scripts/check_android_ci_prerequisites.sh), which discovers SDKs in the standard Linux locations when the environment variable is missing. A runner should still export `ANDROID_SDK_ROOT` explicitly so all Android tooling uses the same installation.

The workflow first bootstraps the Android SDK tools, then runs `flutter build apk --debug`, starts an API 31 `google_atd` `pixel_4` emulator with software acceleration through `scripts/run_android_emulator_ci.sh`, waits for the Android `package`, `input`, and `settings` services to remain stable across repeated checks, and runs every file in `zstandard_android/example/integration_test/`. The Android Test Device image is intentionally used for headless testing because these package tests do not require Google Play services. GPS is disabled in the generated AVD because location is outside this test scope and can require host networking unavailable on a minimal headless runner. A missing SDK or platform tools fails before the test starts with a diagnostic message. Software emulation is slower than KVM and is given a longer job/boot timeout. The launcher does not run optional input or animation setup commands before the Android system services are ready, and each ADB operation is bounded by a timeout to prevent an offline daemon from hanging the job; if boot or readiness fails, it prints the emulator log and Android logcat for diagnosis.

The two Android instrumentation variants run sequentially. They share the runner's ADB daemon, and concurrent software emulators can leave one device offline even after it has booted successfully. The pub-cache variant still runs when the repository-source variant fails, so both dependency resolution paths remain observable.

## Linux job requirements

The workflow builds `zstandard_linux/example` with `flutter build linux --debug`. It then runs the single desktop integration-test file under Xvfb. The same sequence is repeated after removing the repository copy of `zstandard_native`, which verifies resolution from the published package cache.

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
- Pub-cache jobs prove that published `zstandard_native` artifacts can be consumed instead of an in-repository path.
- Coverage and publish dry runs remain package-level quality gates.
