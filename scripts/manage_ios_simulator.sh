#!/usr/bin/env bash
# Manage iOS Simulator for integration tests.
# Usage: ./scripts/manage_ios_simulator.sh <command>
# Commands: start | stop | list | status | device-id
#
# Requires: Xcode and xcrun (macOS only).

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Prefer iPhone 15 or similar; fallback to first available iPhone
DEVICE_NAME="${ZSTANDARD_IOS_DEVICE:-iPhone 16}"
BOOT_TIMEOUT="${ZSTANDARD_IOS_BOOT_TIMEOUT:-60}"

cmd_list() {
  echo "Available simulators:"
  xcrun simctl list devices available 2>/dev/null | grep -E "iPhone|iPad" | head -20
}

cmd_status() {
  local booted
  booted=$(xcrun simctl list devices | grep -E "Booted" | head -1)
  if [[ -n "$booted" ]]; then
    echo "Simulator running: $booted"
    return 0
  fi
  echo "No simulator booted."
  return 1
}

cmd_device_id() {
  # Flutter expects device ID from `flutter devices`; iOS simulators show as "iPhone XX (mobile)"
  # When running with -d, we can use id from simctl
  local uuid
  uuid=$(xcrun simctl list devices | grep -E "Booted" | head -1 | sed -n 's/.*(\([A-F0-9-]*\)) (Booted).*/\1/p')
  if [[ -n "$uuid" ]]; then
    echo "$uuid"
    return 0
  fi
  # Return device name for flutter (e.g. "iPhone 16") as fallback
  echo "$DEVICE_NAME"
  return 0
}

wait_for_boot() {
  echo "Waiting for simulator to boot (timeout ${BOOT_TIMEOUT}s)..."
  local elapsed=0
  while [[ $elapsed -lt $BOOT_TIMEOUT ]]; do
    if xcrun simctl list devices | grep -q "Booted"; then
      echo "Simulator booted."
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  echo "Error: Simulator did not boot within ${BOOT_TIMEOUT}s." >&2
  return 1
}

cmd_start() {
  if xcrun simctl list devices | grep -q "Booted"; then
    echo "Simulator already booted."
    cmd_device_id
    return 0
  fi
  # Find device by name (e.g. "iPhone 16") and boot by UUID
  local uuid
  uuid=$(xcrun simctl list devices available | grep "$DEVICE_NAME" | head -1 | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p')
  if [[ -z "$uuid" ]]; then
    # Fallback: any available iPhone
    uuid=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p')
  fi
  if [[ -z "$uuid" ]]; then
    echo "Error: No available iPhone simulator found. Run 'xcrun simctl list devices available'." >&2
    exit 1
  fi
  echo "Booting simulator $DEVICE_NAME ($uuid)..."
  xcrun simctl boot "$uuid" 2>/dev/null || true
  wait_for_boot
  cmd_device_id
}

cmd_stop() {
  local uuid
  uuid=$(xcrun simctl list devices | grep -E "Booted" | head -1 | sed -n 's/.*(\([A-F0-9-]*\)) (Booted).*/\1/p')
  if [[ -n "$uuid" ]]; then
    echo "Shutting down simulator $uuid..."
    xcrun simctl shutdown "$uuid"
    echo "Simulator stopped."
  else
    echo "No simulator booted."
  fi
}

case "${1:-}" in
  start)     cmd_start ;;
  stop)      cmd_stop ;;
  list)      cmd_list ;;
  status)    cmd_status ;;
  device-id) cmd_device_id ;;
  *)
    echo "Usage: $0 {start|stop|list|status|device-id}" >&2
    echo "  start     - Boot iOS simulator (default: $DEVICE_NAME)" >&2
    echo "  stop      - Shutdown booted simulator" >&2
    echo "  list      - List available simulators" >&2
    echo "  status    - Print boot status" >&2
    echo "  device-id - Print device ID for flutter test -d" >&2
    exit 1
    ;;
esac
