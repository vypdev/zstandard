# Emulator and Simulator Setup

This document describes how to set up Android emulators and iOS simulators for running integration tests locally and in CI. It applies to macOS hosts.

## Android Emulator

### CI (GitHub Actions)

The push and release workflows use [ReactiveCircus/android-emulator-runner](https://github.com/ReactiveCircus/android-emulator-runner) to start an emulator (API 30, `google_apis`, `pixel_4`) and run the Android integration tests. No local script is used in CI.

### Local: Prerequisites

- **Android SDK**: Install via [Android Studio](https://developer.android.com/studio) or the [command-line tools](https://developer.android.com/studio#command-tools). Set `ANDROID_HOME` or `ANDROID_SDK_ROOT` to the SDK root (e.g. `~/Library/Android/sdk` on macOS).
- **Platform tools**: Include `adb` (usually in `$ANDROID_HOME/platform-tools`).
- **Emulator**: Install the "Android Emulator" package and a system image from SDK Manager (e.g. API 30, `google_apis`, `x86_64` or `arm64-v8a` for Apple Silicon).

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

## Web (Chrome + ChromeDriver)

Web tests run in Chrome. The script runs both **unit tests** (`flutter test -d chrome`) and **integration tests** (`flutter drive` with a local web server and ChromeDriver).

### Prerequisites

- **Chrome**: Installed and on PATH.
- **ChromeDriver** (for integration tests only): Must be on PATH and listen on port **4444**. Flutter uses it to drive the browser for integration tests.
  - Install: `brew install chromedriver` (macOS), or [download](https://googlechromelabs.github.io/chrome-for-testing/) a version that matches your Chrome.
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
2. **Integration tests** via `flutter drive --target=integration_test/... -d web-server`, which starts a local server and uses ChromeDriver to control Chrome (headless). If ChromeDriver is not running on port 4444, the script tries to start it; if that fails, integration tests are skipped and the script still succeeds if unit tests passed.

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
- **CI**: Self-hosted runners with pre-created AVDs and simulators can reduce job time. Ensure `ANDROID_HOME` (or `ANDROID_SDK_ROOT`) and Xcode are configured on the runner.
