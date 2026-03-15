#!/usr/bin/env bash
# Sync the canonical zstd C source from the repo root zstd/ into the iOS and
# macOS plugin Class trees so CocoaPods can see the sources (it only globs
# inside the pod directory). Single source of truth remains zstd/ at repo root.
#
# Usage: from repo root, run: ./scripts/sync_zstd_ios_macos.sh
# Or: called automatically by the example app Podfile pre_install hook.
#
# Source of truth: zstd/ (at repo root)
# Targets:
#   - zstandard_ios/ios/Classes/zstd/
#   - zstandard_macos/macos/Classes/zstd/
#
# After syncing, module.modulemap is removed from both copies so the pods build
# without legacy ZSTD_parameters conflicts.

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

echo "Syncing zstd from $SRC"
echo "  -> iOS:  $IOS_ZSTD"
echo "  -> macOS: $MACOS_ZSTD"

# Remove existing copies so the sync is a clean copy (no leftover files from older zstd).
rm -rf "$IOS_ZSTD"
rm -rf "$MACOS_ZSTD"

# Copy from canonical source
mkdir -p "$IOS_ZSTD"
rsync -a "$SRC/" "$IOS_ZSTD/"

# iOS pod: remove module map so the compiler does not load zstd.h for every .c file.
# Legacy files (e.g. zstd_v04.c) define their own ZSTD_parameters with .windowLog; the
# public zstd.h has .cParams.windowLog — without the module map, legacy use their local type.
if [[ -f "$IOS_ZSTD/module.modulemap" ]]; then
  rm -f "$IOS_ZSTD/module.modulemap"
  echo "  Removed module.modulemap from iOS copy (legacy ZSTD_parameters conflict)."
fi

# Copy to macOS
mkdir -p "$MACOS_ZSTD"
rsync -a "$SRC/" "$MACOS_ZSTD/"

# macOS pod builds without the zstd module map to avoid macro/module issues.
if [[ -f "$MACOS_ZSTD/module.modulemap" ]]; then
  rm -f "$MACOS_ZSTD/module.modulemap"
  echo "  Removed module.modulemap from macOS copy (not used by the pod)."
fi

echo "Done. iOS and macOS plugin Class trees are in sync with zstd/."
