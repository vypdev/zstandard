#!/usr/bin/env bash

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <command> [args...]" >&2
  exit 2
fi

api_level="${ANDROID_API_LEVEL:-30}"
target="${ANDROID_SYSTEM_IMAGE_TARGET:-aosp_atd}"
arch="${ANDROID_SYSTEM_IMAGE_ARCH:-x86_64}"
avd_name="${ANDROID_AVD_NAME:-zstandard_ci_test}"
emulator_port="${EMULATOR_PORT:-5554}"

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$sdk_root" || ! -d "$sdk_root" ]]; then
  echo "ANDROID_SDK_ROOT or ANDROID_HOME must point to an Android SDK." >&2
  exit 1
fi

find_sdk_tool() {
  local tool_name="$1"
  local candidate

  candidate="$(command -v "$tool_name" 2>/dev/null || true)"
  if [[ -n "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  candidate="$(find "$sdk_root/cmdline-tools" -type f -path "*/bin/${tool_name}" -print -quit 2>/dev/null || true)"
  if [[ -n "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  echo "Android SDK tool not found: ${tool_name}" >&2
  return 1
}

sdkmanager_bin="$(find_sdk_tool sdkmanager)"
avdmanager_bin="$(find_sdk_tool avdmanager)"
adb_bin="$sdk_root/platform-tools/adb"
emulator_bin="$sdk_root/emulator/emulator"

for required_file in "$adb_bin" "$emulator_bin"; do
  if [[ ! -x "$required_file" ]]; then
    echo "Required Android SDK executable is missing: ${required_file}" >&2
    exit 1
  fi
done

export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"
export PATH="$sdk_root/platform-tools:$sdk_root/emulator:$PATH"

echo "Installing Android emulator prerequisites..."
set +o pipefail
yes 2>/dev/null | "$sdkmanager_bin" --licenses >/dev/null
set -o pipefail
"$sdkmanager_bin" --install \
  "build-tools;37.0.0" \
  platform-tools \
  emulator \
  "platforms;android-${api_level}" \
  "system-images;android-${api_level};${target};${arch}" >/dev/null

echo "Creating AVD ${avd_name}..."
echo no | "$avdmanager_bin" create avd \
  --force \
  --name "$avd_name" \
  --abi "${target}/${arch}" \
  --package "system-images;android-${api_level};${target};${arch}" \
  --device pixel_2

avd_config="$HOME/.android/avd/${avd_name}.avd/config.ini"
# Location is outside the scope of these integration tests.
printf 'hw.cpu.ncore=2\nhw.gps=no\n' >> "$avd_config"

device="emulator-${emulator_port}"
export EMULATOR_PORT="$emulator_port"
emulator_log="${RUNNER_TEMP:-/tmp}/${avd_name}-${emulator_port}.log"
rm -f "$emulator_log"

adb_timeout_seconds="${ANDROID_ADB_TIMEOUT_SECONDS:-30}"

timeout "$adb_timeout_seconds" "$adb_bin" start-server >/dev/null
timeout "$adb_timeout_seconds" "$adb_bin" -s "$device" emu kill >/dev/null 2>&1 || true

echo "Starting software Android emulator on port ${emulator_port}..."
"$emulator_bin" \
  -port "$emulator_port" \
  -avd "$avd_name" \
  -no-window \
  -gpu swiftshader_indirect \
  -feature -Vulkan \
  -feature -GnssGrpcV1 \
  -no-snapshot \
  -no-snapshot-save \
  -noaudio \
  -no-boot-anim \
  -camera-back none \
  -accel off > "$emulator_log" 2>&1 &
emulator_pid=$!

cleanup() {
  local exit_code=$?

  if (( exit_code != 0 )); then
    local diagnostics_file="${RUNNER_TEMP:-/tmp}/${avd_name}-${emulator_port}-diagnostics.txt"
    {
      echo "Android integration diagnostics for ${device}"
      echo "Collected at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
      echo
      echo "== Device state =="
      timeout "$adb_timeout_seconds" "$adb_bin" -s "$device" get-state || true
      timeout "$adb_timeout_seconds" "$adb_bin" -s "$device" shell getprop sys.boot_completed || true
      timeout "$adb_timeout_seconds" "$adb_bin" -s "$device" shell getprop dev.bootcomplete || true
      echo
      echo "== Running processes =="
      timeout "$adb_timeout_seconds" "$adb_bin" -s "$device" shell ps -A || true
      echo
      echo "== Resolved activities =="
      timeout "$adb_timeout_seconds" "$adb_bin" -s "$device" shell cmd package resolve-activity --brief dev.vyp.zstandard_android_example || true
      echo
      echo "== Activity manager =="
      timeout "$adb_timeout_seconds" "$adb_bin" -s "$device" shell dumpsys activity activities || true
      echo
      echo "== Package manager =="
      timeout "$adb_timeout_seconds" "$adb_bin" -s "$device" shell dumpsys package dev.vyp.zstandard_android_example || true
      echo
      echo "== Complete logcat (all buffers) =="
      timeout "$adb_timeout_seconds" "$adb_bin" -s "$device" logcat -b all -d -t 2000 || true
    } > "$diagnostics_file" 2>&1
    echo "Android diagnostics (${diagnostics_file}):" >&2
    tail -n 350 "$diagnostics_file" >&2 || true
  fi

  timeout "$adb_timeout_seconds" "$adb_bin" -s "$device" emu kill >/dev/null 2>&1 || true
  if kill -0 "$emulator_pid" >/dev/null 2>&1; then
    kill "$emulator_pid" >/dev/null 2>&1 || true
    wait "$emulator_pid" >/dev/null 2>&1 || true
  fi

  if (( exit_code != 0 )); then
    echo "Android emulator log (${emulator_log}):" >&2
    tail -n 250 "$emulator_log" >&2 || true
  fi

  exit "$exit_code"
}
trap cleanup EXIT

echo "Waiting for Android emulator boot..."
boot_timeout_seconds=900
boot_started_at="$(date +%s)"
while true; do
  boot_state="$( timeout "$adb_timeout_seconds" "$adb_bin" -s "$device" shell getprop sys.boot_completed 2>/dev/null || true )"
  if [[ "$boot_state" == *"1"* ]]; then
    echo "Android emulator boot completed."
    break
  fi

  if (( $(date +%s) - boot_started_at >= boot_timeout_seconds )); then
    echo "Android emulator did not boot within ${boot_timeout_seconds} seconds." >&2
    exit 1
  fi
  if ! kill -0 "$emulator_pid" >/dev/null 2>&1; then
    echo "Android emulator exited before boot completed." >&2
    exit 1
  fi
  sleep 2
done

bash scripts/wait_for_android_ci_services.sh
"$@"
