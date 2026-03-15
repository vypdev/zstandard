#!/usr/bin/env bash
# Verify the canonical zstd source at repo root exists. iOS and macOS now
# reference zstd/ directly from the podspec (no copy/sync).
#
# Usage: from repo root, run: ./scripts/sync_zstd_ios_macos.sh
#
# After updating zstd: run ./scripts/update_zstd.sh then ./scripts/regenerate_bindings.sh

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/zstd"

if [[ ! -d "$SRC" || ! -f "$SRC/zstd.h" ]]; then
  echo "Error: Canonical zstd source not found at $SRC (expected zstd.h and subdirs)."
  echo "Run: ./scripts/update_zstd.sh   # fetches from github.com/facebook/zstd"
  exit 1
fi

echo "Canonical zstd at $SRC is present. iOS and macOS reference it directly."
