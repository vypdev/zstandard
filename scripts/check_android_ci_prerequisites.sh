#!/usr/bin/env bash
# Discover and validate the Android SDK and Linux emulator prerequisites.
# The script may write GITHUB_ENV/GITHUB_PATH when it runs inside Actions.

set -euo pipefail

find_sdk_root() {
  local candidate

  for candidate in \
    "${ANDROID_SDK_ROOT:-}" \
    "${ANDROID_HOME:-}" \
    "$HOME/Android/Sdk" \
    "$HOME/.android/sdk" \
    "/opt/android-sdk" \
    "/opt/android-sdk-linux" \
    "/usr/local/lib/android/sdk" \
    "/root/Android/Sdk" \
    "/root/.android/sdk"; do
    if [[ -n "$candidate" && -x "$candidate/platform-tools/adb" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  local adb_path
  for search_root in /opt /usr/local /root /home; do
    [[ -d "$search_root" ]] || continue
    adb_path=$(find "$search_root" -type f -path '*/platform-tools/adb' -executable -print -quit 2>/dev/null || true)
    if [[ -n "$adb_path" ]]; then
      candidate="${adb_path%/platform-tools/adb}"
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Android CI prerequisites must be checked on Linux."
  exit 1
fi

SDK_ROOT=$(find_sdk_root || true)
if [[ -z "$SDK_ROOT" ]]; then
  echo "Android SDK not found. Configure ANDROID_SDK_ROOT/ANDROID_HOME or install an SDK containing platform-tools and emulator." >&2
  exit 1
fi

echo "Using Android SDK: $SDK_ROOT"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "ANDROID_SDK_ROOT=$SDK_ROOT" >> "$GITHUB_ENV"
  echo "ANDROID_HOME=$SDK_ROOT" >> "$GITHUB_ENV"
fi
if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$SDK_ROOT/platform-tools" >> "$GITHUB_PATH"
  echo "$SDK_ROOT/emulator" >> "$GITHUB_PATH"
fi

"$SDK_ROOT/platform-tools/adb" version
if [[ ! -e /dev/kvm ]]; then
  echo "KVM is required for the Android emulator on Linux (/dev/kvm is missing)." >&2
  exit 1
fi

if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
  echo "The runner account needs read/write access to /dev/kvm for the Android emulator." >&2
  exit 1
fi

echo "Android SDK and KVM prerequisites are available."
