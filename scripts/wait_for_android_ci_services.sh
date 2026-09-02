#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${EMULATOR_PORT:-}" ]]; then
  echo "EMULATOR_PORT must be set by android-emulator-runner." >&2
  exit 1
fi

device="emulator-${EMULATOR_PORT}"
max_attempts=120

echo "Waiting for Android package services on ${device}..."
adb -s "$device" wait-for-device

for attempt in $(seq 1 "$max_attempts"); do
  if packages="$(adb -s "$device" shell cmd package list packages 2>/dev/null)" && [[ "$packages" == *"package:"* ]]; then
    echo "Android package services are ready after attempt ${attempt}."
    exit 0
  fi

  sleep 5
done

echo "Android package services did not become ready within $((max_attempts * 5)) seconds." >&2
adb -s "$device" get-state >&2 || true
adb -s "$device" shell getprop sys.boot_completed >&2 || true
adb -s "$device" shell cmd package list packages >&2 || true
exit 1
