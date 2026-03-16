# Emulator and Simulator Setup

This document describes how to set up Android emulators and iOS simulators for running integration tests locally and in CI. It applies to macOS hosts.

## Android Emulator

### Architecture (Apple Silicon vs Intel)

On **Apple Silicon (M1/M2/M3)** the script uses an **arm64-v8a** system image so the emulator runs natively. Using x86_64 on ARM often causes the emulator process to exit immediately. On **Intel Macs** it uses **x86_64**. The AVD name includes the ABI (e.g. `zstandard_test_arm64` or `zstandard_test_x86_64`).

### Prerequisites

- **Android SDK**: Install via [Android Studio](https://developer.android.com/studio) or the [command-line tools](https://developer.android.com/studio#command-tools). Set `ANDROID_HOME` or `ANDROID_SDK_ROOT` to the SDK root (e.g. `~/Library/Android/sdk` on macOS).
- **Platform tools**: Include `adb` (usually in `$ANDROID_HOME/platform-tools`).
- **Emulator**: Install the "Android Emulator" package from SDK Manager.
- **System image**: The script installs the correct image for your CPU. On Apple Silicon you may need to install once: `sdkmanager --install "system-images;android-30;google_apis;arm64-v8a"`.

### Script: `scripts/manage_android_emulator.sh`

The repository provides a script to create, start, stop, and query the emulator:

| Command     | Description |
|------------|-------------|
| `create`   | Create an AVD (default `zstandard_test_arm64` or `zstandard_test_x86_64` by arch, or `$ZSTANDARD_AVD_NAME`) if it does not exist. Uses the correct system image for your CPU (arm64-v8a on Apple Silicon, x86_64 on Intel). |
| `start`    | Start the emulator in headless mode and wait for boot. Creates the AVD if missing. |
| `stop`     | Stop the running emulator and clean up. |
| `status`   | Print whether the emulator is running. |
| `device-id`| Print the device ID for use with `flutter test -d <device-id>`. |

**Environment variables:**

- `ZSTANDARD_AVD_NAME`: AVD name (default: `zstandard_test_arm64` on arm64 Macs, `zstandard_test_x86_64` on Intel).
- `ZSTANDARD_AVD_API_LEVEL`: API level for the system image (default: `30`).
- `ZSTANDARD_AVD_BOOT_TIMEOUT`: Boot completion timeout in seconds (default: `240`). Increase on slow machines (e.g. `300`).
- `ZSTANDARD_AVD_DEVICE_READY_TIMEOUT`: Time to wait for the emulator to appear in `adb devices` (default: `60`).

**Example:**

```bash
# From repo root
export ANDROID_HOME=~/Library/Android/sdk
./scripts/manage_android_emulator.sh create   # once
./scripts/manage_android_emulator.sh start
./scripts/test_android_integration.sh
./scripts/manage_android_emulator.sh stop
```

### Installing a system image

If `create` fails because no system image is installed:

```bash
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "system-images;android-30;google_apis;x86_64"
```

Then run `./scripts/manage_android_emulator.sh create` again.

### Troubleshooting

- **"adb not found"**: Ensure `platform-tools` is installed and that `ANDROID_HOME` (or `ANDROID_SDK_ROOT`) is set.
- **"emulator not found"**: Install the Android Emulator package via SDK Manager.
- **Emulator does not boot**: Increase `ZSTANDARD_AVD_BOOT_TIMEOUT` or check that the system image matches the host (e.g. `x86_64` on Intel Macs; ARM images for Apple Silicon may be used where available).
- **"No device/emulator found"**: Run `./scripts/manage_android_emulator.sh start` and wait until `device-id` returns a value before running tests.
- **"Emulator did not boot within Xs"**: First boot can take several minutes. Set a higher timeout: `ZSTANDARD_AVD_BOOT_TIMEOUT=300 ./scripts/test_android_integration.sh`, or skip Android in the full suite: `ZSTANDARD_SKIP_ANDROID=1 ./scripts/test_all_integration.sh`.
- **"Emulator process died before device appeared"**: Usually means the wrong ABI for your Mac. On Apple Silicon you must use an **arm64-v8a** system image; the script now selects it automatically. If you had an old AVD (e.g. `zstandard_test` with x86_64), the script now uses a different AVD name per arch (`zstandard_test_arm64` / `zstandard_test_x86_64`). Install the image: `sdkmanager --install "system-images;android-30;google_apis;arm64-v8a"` (for M1/M2). Check the emulator log: `cat .android_emulator.log` in the repo root.

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

- **Android**: Reuse a single emulator and avoid stopping it between test runs to save boot time. The test script can leave the emulator running; use `manage_android_emulator.sh stop` when done.
- **iOS**: Similarly, leaving the simulator booted between runs avoids repeated boot time.
- **CI**: Self-hosted runners with pre-created AVDs and simulators can reduce job time. Ensure `ANDROID_HOME` (or `ANDROID_SDK_ROOT`) and Xcode are configured on the runner.
