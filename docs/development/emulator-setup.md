# Emulator and Simulator Setup

This document describes how to set up Android emulators, iOS simulators, Linux desktop dependencies, and Chrome for running integration tests locally and in CI.

## Android Emulator

### CI (GitHub Actions)

The push and release workflows use `scripts/run_android_emulator_ci.sh` on the `[self-hosted, Linux]` runner to install the required SDK components, create an API 31 `google_atd` `pixel_4` AVD, and run the Android integration tests. The Android Test Device image avoids Google Play services that are not needed by this package's tests and is suitable for headless execution. The generated AVD disables GPS because the tests do not use location and a headless runner may not provide the IPv6 loopback needed by the emulator's GNSS socket. The workflow builds the APK first and explicitly uses software emulation because the current self-hosted runner does not expose `/dev/kvm`. The launcher intentionally starts the emulator directly instead of using a generic action whose unconditional input-unlock step is unreliable while this slow software image is still bringing up Android services. Before Flutter starts, `scripts/wait_for_android_ci_services.sh` requires the package, input, and settings services plus the package manager to pass a single combined `adb` probe repeatedly for 90 seconds; this avoids relying on the image's early `boot_completed` signal without multiplying slow ADB round trips. Every ADB operation has its own timeout so a stalled ADB daemon cannot consume the whole job silently; `ANDROID_ADB_TIMEOUT_SECONDS` can override the 30-second default. If boot or readiness times out, the launcher prints the emulator log and the readiness script prints Android logcat output.

### Local: Prerequisites

- **Android SDK**: Install via [Android Studio](https://developer.android.com/studio) or the [command-line tools](https://developer.android.com/studio#command-tools). Set `ANDROID_HOME` or `ANDROID_SDK_ROOT` to the SDK root (e.g. `~/Library/Android/sdk` on macOS).
- **Platform tools**: Include `adb` (usually in `$ANDROID_HOME/platform-tools`).
- **Emulator**: Install the "Android Emulator" package and a system image from SDK Manager (e.g. API 30, `google_apis`, `x86_64` or `arm64-v8a` for Apple Silicon).
- **Linux CI**: `/dev/kvm` is recommended for speed, but the current workflow can run without it using software emulation.

### Local: Running integration tests

1. **Start an emulator** from Android Studio (AVD Manager → Play) or from the command line:
   ```bash
   emulator -avd <your_avd_name> -no-window &
   ```
   Wait until the device appears in `adb devices` and is fully booted.

2. **Run the tests** from the repo root:
   ```bash
   ./scripts/test_android_integration.sh
   ```
   The script picks the first connected device/emulator. To use a specific device: `FLUTTER_DEVICE_ID=<id> ./scripts/test_android_integration.sh` (get `<id>` from `flutter devices`).

### Installing a system image

If you need to create an AVD, install a system image first, then create the AVD in Android Studio or with `avdmanager`:

```bash
# Intel / AMD (x86_64)
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "system-images;android-30;google_apis;x86_64"

# Apple Silicon (arm64-v8a)
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "system-images;android-30;google_apis;arm64-v8a"
```

### Troubleshooting

- **"adb not found"**: Ensure `platform-tools` is installed and that `ANDROID_HOME` (or `ANDROID_SDK_ROOT`) is set.
- **"No Android device or emulator found"**: Start an emulator from Android Studio or run `emulator -avd <avd> -no-window &`, then run the script again. Use `flutter devices` to confirm the device is visible.
- **To skip Android** in the full integration suite: `ZSTANDARD_SKIP_ANDROID=1 ./scripts/test_all_integration.sh`.

---

## iOS Simulator

### Prerequisites

- **Xcode**: Install from the Mac App Store. Accept the license and install additional components if prompted.
- **Command Line Tools**: `xcode-select --install` if needed. Simulators are controlled via `xcrun simctl`.

### Script: `scripts/manage_ios_simulator.sh`

| Command     | Description |
|------------|-------------|
| `start`    | Boot a simulator (default device: `iPhone 16`, overridable with `ZSTANDARD_IOS_DEVICE`). |
| `stop`     | Shut down the booted simulator. |
| `list`     | List available simulators. |
| `status`   | Print whether a simulator is booted. |
| `device-id`| Print the device ID (UUID or name) for `flutter test -d <device-id>`. |

**Environment variables:**

- `ZSTANDARD_IOS_DEVICE`: Device name (e.g. `iPhone 16`, `iPhone 15`). Default: `iPhone 16`.
- `ZSTANDARD_IOS_BOOT_TIMEOUT`: Boot wait timeout in seconds (default: `60`).

**Example:**

```bash
./scripts/manage_ios_simulator.sh start
./scripts/test_ios_integration.sh
./scripts/manage_ios_simulator.sh stop   # optional
```

### Troubleshooting

- **"No available iPhone simulator"**: Open Xcode → Window → Devices and Simulators and download a simulator runtime, or run `xcrun simctl list devices available` to see what is installed. Adjust `ZSTANDARD_IOS_DEVICE` to a device you have (e.g. `iPhone 15`).
- **Simulator already booted**: The script will reuse the booted simulator. Use `device-id` to get the ID for `flutter test -d`.
- **Flutter cannot find device**: Ensure the simulator is booted and run `flutter devices` to confirm the device id; then pass that id to `flutter test integration_test/ -d <id>`.

---

## Linux desktop

Linux integration tests require CMake, Ninja, Clang, `pkg-config`, GTK 3 development headers, and Xvfb on headless runners. The CI workflow installs these through [`.github/actions/setup-linux-dependencies/action.yml`](../../.github/actions/setup-linux-dependencies/action.yml), then runs:

```bash
cd zstandard_linux/example
flutter build linux --debug
xvfb-run --auto-servernum flutter test integration_test/ -d linux
```

The Linux runner must be Debian/Ubuntu-based and allow passwordless `sudo` for the dependency setup action.

## Web (Chrome + ChromeDriver)

Web tests run in Chrome. The script runs both **unit tests** (`flutter test -d chrome`) and **integration tests** (`flutter drive` with a local web server and ChromeDriver).

### Prerequisites

- **Chrome**: Installed and on PATH. GitHub Actions installs Chrome for Testing with `browser-actions/setup-chrome@v2`.
- **ChromeDriver** (for integration tests only): Must be on PATH and listen on port **4444**. Flutter uses it to drive the browser for integration tests.
  - Install locally with `brew install chromedriver` (macOS), or [download](https://googlechromelabs.github.io/chrome-for-testing/) a version that matches your Chrome. CI installs the matching driver automatically.
  - **macOS**: If a security popup says "chromedriver cannot be opened" or "Apple could not verify...", remove the quarantine attribute:  
    `xattr -d com.apple.quarantine "$(which chromedriver)"`  
    If that fails (e.g. symlink), use the real binary path (e.g. `/opt/homebrew/Caskroom/chromedriver/<version>/chromedriver-mac-arm64/chromedriver`).
  - See [Flutter: Test in a web browser](https://docs.flutter.dev/testing/integration-tests#web).

### Script: `scripts/test_web_integration.sh`

From the repo root:

```bash
./scripts/test_web_integration.sh
```

This runs:

1. **Unit tests** in Chrome (`zstandard_web` package tests).
2. **Integration tests** via `flutter drive --target=integration_test/... -d web-server`, which starts a local server and uses ChromeDriver to control Chrome. On Linux the script uses Xvfb. If ChromeDriver is unavailable or fails to start, the script fails; use `ZSTANDARD_SKIP_WEB=1` only for an intentional partial local run.

### Running integration tests manually

If the script skips integration tests (ChromeDriver not available), start ChromeDriver in another terminal, then run the script again:

```bash
# Terminal 1
chromedriver --port=4444

# Terminal 2 (repo root)
./scripts/test_web_integration.sh
```

Or run only the integration tests from the example app:

```bash
chromedriver --port=4444 &
cd zstandard_web/example
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/zstandard_web_integration_test.dart \
  -d web-server --web-port=8080
```

### Unit tests only (no ChromeDriver)

From `zstandard_web`:

```bash
flutter test -d chrome
```

---

## Performance tips

- **Android**: Reuse a single emulator and avoid closing it between test runs to save boot time. Leave the emulator running and run `./scripts/test_android_integration.sh` as needed.
- **iOS**: Similarly, leaving the simulator booted between runs avoids repeated boot time.
- **CI**: Self-hosted runners with pre-created AVDs and simulators can reduce job time. Ensure `ANDROID_HOME` (or `ANDROID_SDK_ROOT`) is available for Linux Android jobs; KVM is optional for the current software-emulation configuration, and Xcode is configured for Apple jobs.
