#!/usr/bin/env bash
# Sync the canonical zstd C source from zstandard_macos/src into the iOS and
# macOS plugin Class trees so both platforms use the same zstd version.
#
# Usage: from repo root, run: ./scripts/sync_zstd_ios_macos.sh
#
# Source of truth: zstandard_macos/src/
# Targets:
#   - zstandard_ios/ios/Classes/zstd/
#   - zstandard_macos/macos/Classes/zstd/
#
# After syncing, the macOS copy has module.modulemap removed so the pod builds
# without module conflicts (see zstandard_macos.podspec).

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/zstandard_macos/src"
IOS_ZSTD="$ROOT/zstandard_ios/ios/Classes/zstd"
MACOS_ZSTD="$ROOT/zstandard_macos/macos/Classes/zstd"

if [[ ! -d "$SRC" || ! -f "$SRC/zstd.h" ]]; then
  echo "Error: Canonical zstd source not found at $SRC (expected zstd.h and subdirs)."
  exit 1
fi

echo "Syncing zstd from $SRC"
echo "  -> iOS:  $IOS_ZSTD"
echo "  -> macOS: $MACOS_ZSTD"

# Sync to iOS (destination must exist for rsync; mkdir -p)
mkdir -p "$IOS_ZSTD"
rsync -a --delete "$SRC/" "$IOS_ZSTD/"

# iOS pod: remove module map so the compiler does not load zstd.h for every .c file.
# Legacy files (e.g. zstd_v04.c) define their own ZSTD_parameters with .windowLog; the
# public zstd.h has .cParams.windowLog — without the module map, legacy use their local type.
if [[ -f "$IOS_ZSTD/module.modulemap" ]]; then
  rm -f "$IOS_ZSTD/module.modulemap"
  echo "  Removed module.modulemap from iOS copy (legacy ZSTD_parameters conflict)."
fi

# Sync to macOS
mkdir -p "$MACOS_ZSTD"
rsync -a --delete "$SRC/" "$MACOS_ZSTD/"

# macOS pod builds without the zstd module map to avoid macro/module issues.
if [[ -f "$MACOS_ZSTD/module.modulemap" ]]; then
  rm -f "$MACOS_ZSTD/module.modulemap"
  echo "  Removed module.modulemap from macOS copy (not used by the pod)."
fi

echo "Done. iOS and macOS plugin Class trees are in sync with zstandard_macos/src."
