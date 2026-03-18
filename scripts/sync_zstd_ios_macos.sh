#!/usr/bin/env bash
# Sync the canonical zstd C source from zstandard_native into the iOS and/or
# macOS plugin Class trees so CocoaPods can see the sources (it only globs
# inside the pod directory). Single source of truth is zstandard_native/src/zstd/.
#
# Usage:
#   ./scripts/sync_zstd_ios_macos.sh ios   # sync only to zstandard_ios/ios/Classes/zstd/
#   ./scripts/sync_zstd_ios_macos.sh macos # sync only to zstandard_macos/macos/Classes/zstd/
#   ./scripts/sync_zstd_ios_macos.sh       # sync both (e.g. when run manually from repo root)
#
# Resolves zstd source: 1) ROOT/zstandard_native/src/zstd, 2) pub-cache via package_config.json.
# Each pod runs this with its platform in before_compile/before_headers and removes its copy in a script phase with execution_position :any (as late as possible).

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Prefer repo local zstandard_native/src/zstd
SRC="$ROOT/zstandard_native/src/zstd"

if [[ ! -d "$SRC" || ! -f "$SRC/zstd.h" ]]; then
  # 2. Try package_config.json (e.g. from zstandard_ios or zstandard_macos after pub get)
  for CONFIG in "$ROOT/zstandard_ios/.dart_tool/package_config.json" \
                 "$ROOT/zstandard_macos/.dart_tool/package_config.json"; do
    if [[ -f "$CONFIG" ]]; then
      NATIVE_ROOT=$(grep -A 2 '"name": "zstandard_native"' "$CONFIG" 2>/dev/null | grep '"rootUri"' | sed -n 's/.*"rootUri": "file:\/\/\([^"]*\)".*/\1/p' | head -1)
      if [[ -n "$NATIVE_ROOT" && -d "$NATIVE_ROOT/src/zstd" && -f "$NATIVE_ROOT/src/zstd/zstd.h" ]]; then
        SRC="$NATIVE_ROOT/src/zstd"
        break
      fi
    fi
  done
fi

if [[ ! -d "$SRC" || ! -f "$SRC/zstd.h" ]]; then
  echo "Error: zstd source not found in zstandard_native (expected zstd.h and subdirs)."
  echo "  Tried: $ROOT/zstandard_native/src/zstd"
  echo "  Run from repo root: ./scripts/update_zstd.sh   # or ensure zstandard_native is resolved (flutter pub get)"
  exit 1
fi

IOS_ZSTD="$ROOT/zstandard_ios/ios/Classes/zstd"
MACOS_ZSTD="$ROOT/zstandard_macos/macos/Classes/zstd"

sync_ios() {
  echo "Syncing zstd from $SRC -> iOS $IOS_ZSTD"
  rm -rf "$IOS_ZSTD"
  mkdir -p "$IOS_ZSTD"
  rsync -a "$SRC/" "$IOS_ZSTD/"
  if [[ -f "$IOS_ZSTD/module.modulemap" ]]; then
    rm -f "$IOS_ZSTD/module.modulemap"
    echo "  Removed module.modulemap from iOS copy (legacy ZSTD_parameters conflict)."
  fi
}

sync_macos() {
  echo "Syncing zstd from $SRC -> macOS $MACOS_ZSTD"
  rm -rf "$MACOS_ZSTD"
  mkdir -p "$MACOS_ZSTD"
  rsync -a "$SRC/" "$MACOS_ZSTD/"
  if [[ -f "$MACOS_ZSTD/module.modulemap" ]]; then
    rm -f "$MACOS_ZSTD/module.modulemap"
    echo "  Removed module.modulemap from macOS copy (not used by the pod)."
  fi
}

case "${1:-}" in
  ios)
    sync_ios
    ;;
  macos)
    sync_macos
    ;;
  *)
    sync_ios
    sync_macos
    echo "Done. iOS and macOS plugin Class trees are in sync with zstandard_native/src/zstd/."
    ;;
esac
