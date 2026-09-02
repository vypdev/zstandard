# Self-hosted CI contract

The repository uses self-hosted runners for platform checks that cannot run reliably on a generic hosted image. The current automated scope is Android, Linux, and Web. Apple and Windows remain separate platform workflows and require their corresponding hardware and toolchain.

## Linux runner labels

The automated non-Apple checks use:

```yaml
runs-on: [self-hosted, Linux]
```

The runner must be Debian/Ubuntu-based and allow the runner account to use passwordless `sudo`. Each job installs and verifies its common toolchain through [`.github/actions/setup-linux-dependencies/action.yml`](../../.github/actions/setup-linux-dependencies/action.yml), so the runner image does not need a manually maintained copy of CMake or GTK.

The expected baseline is:

- Flutter 3.47.2, selected explicitly by the workflows.
- `build-essential`, Clang, CMake, Ninja, `pkg-config`, and `curl`.
- GTK 3 development headers and Xvfb for Linux/Web desktop jobs.
- `lcov` and `bc` for coverage jobs.

## Android job requirements

In addition to the common Linux baseline, Android jobs require:

- Android SDK root exposed as `ANDROID_SDK_ROOT` or `ANDROID_HOME`.
- Executable SDK `platform-tools/adb` and `emulator` binaries.
- Java 17.
- Access to `/dev/kvm` for the x86_64 API 30 emulator. The workflow checks read/write access.

The workflow also calls [`scripts/check_android_ci_prerequisites.sh`](../../scripts/check_android_ci_prerequisites.sh), which discovers SDKs in the standard Linux locations when the environment variable is missing. A runner should still export `ANDROID_SDK_ROOT` explicitly so all Android tooling uses the same installation.

The workflow first runs `flutter build apk --debug`, then starts an API 30 `google_apis` `pixel_4` emulator and runs every file in `zstandard_android/example/integration_test/`. A missing SDK, emulator binary, or KVM device fails before the test starts with a diagnostic message.

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
