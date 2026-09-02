#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${EMULATOR_PORT:-}" ]]; then
  echo "EMULATOR_PORT must be set by the Android emulator launcher." >&2
  exit 1
fi

device="emulator-${EMULATOR_PORT}"
max_attempts=30
required_consecutive_successes=4
probe_timeout_seconds=15
probe_interval_seconds=30
adb_timeout_seconds="${ANDROID_ADB_TIMEOUT_SECONDS:-30}"

echo "Waiting for Android package services on ${device}..."
timeout "$adb_timeout_seconds" adb -s "$device" wait-for-device

consecutive_successes=0
for attempt in $(seq 1 "$max_attempts"); do
  services="$(timeout "$probe_timeout_seconds" adb -s "$device" shell '
    service check package
    service check input
    service check settings
    pm path android
  ' 2>/dev/null || true)"

  if [[ "$services" == *"Service package: found"* ]] \
    && [[ "$services" == *"Service input: found"* ]] \
    && [[ "$services" == *"Service settings: found"* ]] \
    && [[ "$services" == *"package:/system/framework/framework-res.apk"* ]] \
    && [[ "$services" == *"package:"* ]]; then
    consecutive_successes=$((consecutive_successes + 1))
    echo "Android package services passed readiness check ${consecutive_successes}/${required_consecutive_successes}."

    if (( consecutive_successes >= required_consecutive_successes )); then
      echo "Android package services are stable after attempt ${attempt}."
      exit 0
    fi
  else
    consecutive_successes=0
  fi

  sleep "$probe_interval_seconds"
done

echo "Android package services did not remain stable for $((required_consecutive_successes * probe_interval_seconds)) seconds within $((max_attempts * probe_interval_seconds)) seconds." >&2
timeout "$adb_timeout_seconds" adb -s "$device" get-state >&2 || true
timeout "$adb_timeout_seconds" adb -s "$device" shell getprop sys.boot_completed >&2 || true
timeout "$adb_timeout_seconds" adb -s "$device" shell 'service check package; service check input; service check settings; pm path android' >&2 || true
timeout "$adb_timeout_seconds" adb -s "$device" logcat -d -b all -t 250 >&2 || true
exit 1
