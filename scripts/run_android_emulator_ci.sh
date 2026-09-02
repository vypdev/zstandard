#!/usr/bin/env bash

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <command> [args...]" >&2
  exit 2
fi

api_level="${ANDROID_API_LEVEL:-31}"
target="${ANDROID_SYSTEM_IMAGE_TARGET:-google_atd}"
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

run_privileged() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo -n "$@"
  else
    echo "Android emulator CI requires root or passwordless sudo to enable IPv6 loopback." >&2
    return 1
  fi
}

ensure_ipv6_loopback() {
  if ! command -v ip >/dev/null 2>&1 || ! command -v sysctl >/dev/null 2>&1; then
    echo "Android emulator CI requires iproute2 and procps to configure IPv6 loopback." >&2
    return 1
  fi

  if ip -6 addr show dev lo scope host 2>/dev/null | grep -Eq 'inet6[[:space:]]+::1/'; then
    return 0
  fi

  echo "Enabling IPv6 loopback required by the Android emulator..."
  run_privileged sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
  run_privileged sysctl -w net.ipv6.conf.lo.disable_ipv6=0 >/dev/null
  run_privileged ip -6 addr add ::1/128 dev lo >/dev/null 2>&1 || true

  if ! ip -6 addr show dev lo scope host 2>/dev/null | grep -Eq 'inet6[[:space:]]+::1/'; then
    echo "Android emulator CI could not enable IPv6 loopback (::1)." >&2
    return 1
  fi
}

ensure_ipv6_loopback

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
  --device pixel_4

avd_config="$HOME/.android/avd/${avd_name}.avd/config.ini"
# The headless runner does not provide a usable IPv6 loopback for the
# emulator's GNSS socket, and these integration tests do not use location.
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
  -no-snapshot \
  -no-snapshot-save \
  -noaudio \
  -no-boot-anim \
  -camera-back none \
  -accel off > "$emulator_log" 2>&1 &
emulator_pid=$!

cleanup() {
  local exit_code=$?

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
