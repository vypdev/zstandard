#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <flutter-apk-directory> <debug|release>" >&2
  exit 2
fi

apk_dir="$1"
build_type="$2"
case "$build_type" in
  debug|release) ;;
  *)
    echo "Unsupported build type: $build_type" >&2
    exit 2
    ;;
esac

readelf_bin="$(command -v readelf || command -v llvm-readelf || true)"
if [[ -z "$readelf_bin" ]] && ! command -v file >/dev/null 2>&1; then
  echo "readelf, llvm-readelf, or file is required to verify Android native library architectures." >&2
  exit 1
fi

temporary_dir=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/zstandard-android-abis.XXXXXX")
cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

for abi in armeabi-v7a arm64-v8a x86_64; do
  apk="$apk_dir/app-${abi}-${build_type}.apk"
  native_library="$temporary_dir/libzstandard_android-${abi}.so"

  if [[ ! -f "$apk" ]]; then
    echo "Missing APK for $abi: $apk" >&2
    exit 1
  fi

  unzip -p "$apk" "lib/${abi}/libzstandard_android.so" > "$native_library"
  case "$abi" in
    armeabi-v7a)
      expected_machine='ARM'
      file_pattern='ARM'
      ;;
    arm64-v8a)
      expected_machine='AArch64'
      file_pattern='ARM aarch64|AArch64'
      ;;
    x86_64)
      expected_machine='Advanced Micro Devices X86-64'
      file_pattern='x86-64|x86_64'
      ;;
  esac

  if [[ -n "$readelf_bin" ]]; then
    machine=$("$readelf_bin" -h "$native_library" | sed -n 's/^ *Machine: *//p')
    if [[ "$machine" != "$expected_machine" ]]; then
      echo "Unexpected machine for $abi: ${machine:-unknown}; expected $expected_machine" >&2
      exit 1
    fi
    echo "$build_type $abi: $machine"
  else
    file_description=$(file "$native_library")
    if ! grep -Eq "$file_pattern" <<<"$file_description"; then
      echo "Unexpected machine for $abi: $file_description" >&2
      exit 1
    fi
    echo "$build_type $abi: $file_description"
  fi
done
