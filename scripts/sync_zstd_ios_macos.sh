#!/usr/bin/env bash
# Sync the canonical zstd C source from the repo root zstd/ into the iOS and/or
# macOS plugin Class trees so CocoaPods can see the sources (it only globs
# inside the pod directory). Single source of truth remains zstd/ at repo root.
#
# Usage:
#   ./scripts/sync_zstd_ios_macos.sh ios   # sync only to zstandard_ios/ios/Classes/zstd/
#   ./scripts/sync_zstd_ios_macos.sh macos # sync only to zstandard_macos/macos/Classes/zstd/
#   ./scripts/sync_zstd_ios_macos.sh       # sync both (e.g. when run manually from repo root)
#
# Each pod runs this with its platform in before_compile and removes its copy in after_compile.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/zstd"
IOS_ZSTD="$ROOT/zstandard_ios/ios/Classes/zstd"
MACOS_ZSTD="$ROOT/zstandard_macos/macos/Classes/zstd"

if [[ ! -d "$SRC" || ! -f "$SRC/zstd.h" ]]; then
  echo "Error: Canonical zstd source not found at $SRC (expected zstd.h and subdirs)."
  echo "Run: ./scripts/update_zstd.sh   # fetches from github.com/facebook/zstd"
  exit 1
fi

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
    echo "Done. iOS and macOS plugin Class trees are in sync with zstd/."
    ;;
esac
