#!/usr/bin/env bash
# Sync zstd C source from zstandard_native into this plugin's macos/Classes/zstd/
# so CocoaPods can see the sources. Works in repo and when published (pub cache).
#
# Usage: ./scripts/sync_zstd.sh
# Resolves zstd from: 1) sibling zstandard_native (repo), 2) package_config.json (pub or repo).

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="$PLUGIN_ROOT/macos/Classes/zstd"

# 1. Repo: sibling zstandard_native
SRC="$PLUGIN_ROOT/../zstandard_native/src/zstd"
if [[ ! -d "$SRC" || ! -f "$SRC/zstd.h" ]]; then
  SRC=""
  # 2. package_config.json (walk up from plugin: plugin itself or app that depends on it)
  SEARCH="$PLUGIN_ROOT"
  while [[ -n "$SEARCH" ]]; do
    if [[ -f "$SEARCH/.dart_tool/package_config.json" ]]; then
      NATIVE_ROOT=$(grep -A 2 '"name": "zstandard_native"' "$SEARCH/.dart_tool/package_config.json" 2>/dev/null | grep '"rootUri"' | sed -n 's/.*"rootUri": "file:\/\/\([^"]*\)".*/\1/p' | head -1)
      if [[ -n "$NATIVE_ROOT" && -d "$NATIVE_ROOT/src/zstd" && -f "$NATIVE_ROOT/src/zstd/zstd.h" ]]; then
        SRC="$NATIVE_ROOT/src/zstd"
        break
      fi
    fi
    SEARCH="${SEARCH%/*}"
    [[ "$SEARCH" = "${SEARCH%/*}" ]] && break
  done
fi

if [[ -z "$SRC" || ! -d "$SRC" || ! -f "$SRC/zstd.h" ]]; then
  echo "Error: zstd source not found (expected zstandard_native/src/zstd with zstd.h)."
  echo "  Run from app or plugin: flutter pub get"
  exit 1
fi

echo "Syncing zstd from $SRC -> $DEST"
rm -rf "$DEST"
mkdir -p "$DEST"
rsync -a "$SRC/" "$DEST/"
if [[ -f "$DEST/module.modulemap" ]]; then
  rm -f "$DEST/module.modulemap"
  echo "  Removed module.modulemap from macOS copy (not used by the pod)."
fi
