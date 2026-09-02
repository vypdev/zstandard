#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${EMULATOR_PORT:-}" ]]; then
  echo "EMULATOR_PORT must be set by the Android emulator launcher." >&2
  exit 1
fi

device="emulator-${EMULATOR_PORT}"
max_attempts=180
required_consecutive_successes=24

echo "Waiting for Android package services on ${device}..."
adb -s "$device" wait-for-device

consecutive_successes=0
for attempt in $(seq 1 "$max_attempts"); do
  packages="$(adb -s "$device" shell cmd package list packages 2>/dev/null || true)"
  framework_path="$(adb -s "$device" shell pm path android 2>/dev/null || true)"
  package_service="$(adb -s "$device" shell service check package 2>/dev/null || true)"

  if [[ "$packages" == *"package:"* ]] \
    && [[ "$framework_path" == *"package:/system/framework/framework-res.apk"* ]] \
    && [[ "$package_service" == *"Service package: found"* ]]; then
    consecutive_successes=$((consecutive_successes + 1))
    echo "Android package services passed readiness check ${consecutive_successes}/${required_consecutive_successes}."

    if (( consecutive_successes >= required_consecutive_successes )); then
      echo "Android package services are stable after attempt ${attempt}."
      exit 0
    fi
  else
    consecutive_successes=0
  fi

  sleep 5
done

echo "Android package services did not remain stable for $((required_consecutive_successes * 5)) seconds within $((max_attempts * 5)) seconds." >&2
adb -s "$device" get-state >&2 || true
adb -s "$device" shell getprop sys.boot_completed >&2 || true
adb -s "$device" shell cmd package list packages >&2 || true
adb -s "$device" shell service check package >&2 || true
adb -s "$device" logcat -d -b all -t 250 >&2 || true
exit 1
