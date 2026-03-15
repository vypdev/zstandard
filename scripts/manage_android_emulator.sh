#!/usr/bin/env bash
# Manage Android emulator for integration tests.
# Usage: ./scripts/manage_android_emulator.sh <command>
# Commands: create | start | stop | status | device-id
#
# Requires: Android SDK with platform-tools and emulator. Set ANDROID_HOME or ANDROID_SDK_ROOT.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

AVD_NAME="${ZSTANDARD_AVD_NAME:-zstandard_test}"
PID_FILE="${ROOT}/.android_emulator.pid"
API_LEVEL="${ZSTANDARD_AVD_API_LEVEL:-30}"
BOOT_TIMEOUT="${ZSTANDARD_AVD_BOOT_TIMEOUT:-240}"
DEVICE_READY_TIMEOUT="${ZSTANDARD_AVD_DEVICE_READY_TIMEOUT:-60}"

log() { echo "[android-emulator] $*"; }
log_step() { echo "[android-emulator] [step] $*"; }
log_wait() { echo "[android-emulator] [wait ${1}s] $2"; }

# Resolve SDK path
log "Using command: ${1:-unknown}"
if [[ -n "$ANDROID_HOME" ]]; then
  SDK="$ANDROID_HOME"
  log "SDK from ANDROID_HOME: $SDK"
elif [[ -n "$ANDROID_SDK_ROOT" ]]; then
  SDK="$ANDROID_SDK_ROOT"
  log "SDK from ANDROID_SDK_ROOT: $SDK"
else
  echo "Error: Set ANDROID_HOME or ANDROID_SDK_ROOT" >&2
  exit 1
fi

EMULATOR="${SDK}/emulator/emulator"
ADB="${SDK}/platform-tools/adb"
AVDMANAGER="${SDK}/cmdline-tools/latest/bin/avdmanager"
SDKMANAGER="${SDK}/cmdline-tools/latest/bin/sdkmanager"

log "adb=$ADB emulator=$EMULATOR avdmanager=$AVDMANAGER"

if [[ ! -x "$ADB" ]]; then
  echo "Error: adb not found at $ADB. Install platform-tools." >&2
  exit 1
fi

if [[ ! -x "$EMULATOR" ]]; then
  echo "Error: emulator not found at $EMULATOR. Install emulator package." >&2
  exit 1
fi

cmd_create() {
  log_step "Checking if AVD $AVD_NAME exists..."
  if "$AVDMANAGER" list avd 2>/dev/null | grep -q "Name: $AVD_NAME"; then
    log "AVD $AVD_NAME already exists."
    return 0
  fi
  log_step "Creating AVD $AVD_NAME (API $API_LEVEL)..."
  if [[ -x "$SDKMANAGER" ]]; then
    log "Ensuring system image is installed..."
    "$SDKMANAGER" --install "system-images;android-${API_LEVEL};google_apis;x86_64" 2>/dev/null || true
  fi
  log "Running avdmanager create avd..."
  echo no | "$AVDMANAGER" create avd --force -n "$AVD_NAME" \
    -k "system-images;android-${API_LEVEL};google_apis;x86_64" \
    -d "pixel_4" 2>/dev/null || {
    echo "Note: If create failed, install system image: $SDKMANAGER --install \"system-images;android-${API_LEVEL};google_apis;x86_64\"" >&2
    exit 1
  }
  log "AVD $AVD_NAME created."
}

cmd_stop() {
  log_step "Stopping emulator..."
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      log "Killing emulator process PID $pid"
      kill "$pid" 2>/dev/null || true
      sleep 2
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    log "Removed PID file."
  fi
  "$ADB" emu kill 2>/dev/null || true
  log "Emulator stopped."
}

cmd_status() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      log "Emulator running (PID $pid)."
      "$ADB" devices 2>/dev/null | head -5
      return 0
    fi
    log "PID file present but process $pid not running; removing PID file."
    rm -f "$PID_FILE"
  fi
  log "Emulator not running."
  return 1
}

cmd_device_id() {
  local dev
  dev=$("$ADB" devices -l 2>/dev/null | grep -E "emulator-[0-9]+|device " | head -1 | awk '{print $1}')
  if [[ -n "$dev" ]]; then
    echo "$dev"
    return 0
  fi
  echo "Error: No device/emulator found. Start emulator first." >&2
  return 1
}

wait_for_boot() {
  log_step "Phase 1: waiting for emulator to appear in 'adb devices' (timeout ${DEVICE_READY_TIMEOUT}s)"
  local elapsed=0
  while [[ $elapsed -lt $DEVICE_READY_TIMEOUT ]]; do
    local dev_out
    dev_out=$("$ADB" devices -l 2>/dev/null || true)
    if echo "$dev_out" | grep -qE "emulator-[0-9]+.*device"; then
      log "Emulator visible in adb devices at ${elapsed}s."
      echo "$dev_out" | head -5 | while read -r line; do log "  $line"; done
      break
    fi
    if [[ -f "$PID_FILE" ]]; then
      local pid
      pid=$(cat "$PID_FILE")
      if kill -0 "$pid" 2>/dev/null; then
        log_wait "$elapsed" "emulator process alive (PID $pid), adb devices: $(echo "$dev_out" | head -3 | tr '\n' ' ')"
      else
        log "Emulator process (PID $pid) has exited. Last adb devices: $dev_out"
        echo "Error: Emulator process died before device appeared." >&2
        return 1
      fi
    else
      log_wait "$elapsed" "no PID file yet; adb devices: $(echo "$dev_out" | head -3 | tr '\n' ' ')"
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  if ! "$ADB" devices 2>/dev/null | grep -qE "emulator-[0-9]+.*device"; then
    log "Final adb devices:"
    "$ADB" devices -l 2>/dev/null | while read -r line; do log "  $line"; done
    echo "Error: Emulator did not appear within ${DEVICE_READY_TIMEOUT}s." >&2
    return 1
  fi

  log_step "Phase 2: waiting for sys.boot_completed=1 (timeout ${BOOT_TIMEOUT}s)"
  elapsed=0
  while [[ $elapsed -lt $BOOT_TIMEOUT ]]; do
    local completed
    completed=$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n ' || echo "?")
    if [[ "$completed" == "1" ]]; then
      log "Boot completed at ${elapsed}s."
      sleep 3
      return 0
    fi
    if [[ $((elapsed % 15)) -eq 0 && $elapsed -gt 0 ]]; then
      log_wait "$elapsed" "sys.boot_completed='$completed' (waiting for '1')"
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  log "Last sys.boot_completed: $("$ADB" shell getprop sys.boot_completed 2>/dev/null || echo "?")"
  echo "Error: Emulator did not boot within ${BOOT_TIMEOUT}s." >&2
  return 1
}

cmd_start() {
  log_step "Checking current status..."
  if cmd_status >/dev/null 2>&1; then
    log "Emulator already running."
    cmd_device_id
    return 0
  fi
  log_step "Stopping any previous emulator and starting adb server..."
  cmd_stop 2>/dev/null || true
  "$ADB" start-server 2>/dev/null || true
  log "adb server started."

  log_step "Checking AVD list..."
  if ! "$AVDMANAGER" list avd 2>/dev/null | grep -q "Name: $AVD_NAME"; then
    log "AVD $AVD_NAME not found, creating..."
    cmd_create
  else
    log "AVD $AVD_NAME exists."
  fi

  log_step "Launching emulator binary: $EMULATOR"
  log "  AVD=$AVD_NAME (headless, no-snapshot, no-audio)"
  "$EMULATOR" -avd "$AVD_NAME" -no-window -gpu swiftshader_indirect -no-snapshot -no-audio -no-boot-anim -no-accelerometer -no-gyroscope -no-sensors -noaudio &
  local pid=$!
  echo $pid > "$PID_FILE"
  log "Emulator started with PID $pid (saved to $PID_FILE)"
  log_step "Sleeping 8s before polling adb..."
  sleep 8
  wait_for_boot
  log_step "Getting device id for flutter..."
  cmd_device_id
}

case "${1:-}" in
  create) cmd_create ;;
  start)  cmd_start ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
  device-id) cmd_device_id ;;
  *)
    echo "Usage: $0 {create|start|stop|status|device-id}" >&2
    echo "  create    - Create AVD if not present" >&2
    echo "  start     - Start emulator (create if needed), wait for boot" >&2
    echo "  stop      - Stop emulator" >&2
    echo "  status    - Print running status" >&2
    echo "  device-id - Print device ID for flutter test -d" >&2
    exit 1
    ;;
esac
