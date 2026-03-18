#!/usr/bin/env bash
# Update the canonical zstd source in zstandard_native/src/zstd/ from the official repo.
# Usage: from repo root, run: ./scripts/update_zstd.sh
# Optional: ./scripts/update_zstd.sh v1.5.6   (tag or branch; default: dev)
#
# Requires: git. After this, run ./scripts/sync_zstd_ios_macos.sh and optionally
# ./scripts/regenerate_bindings.sh.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSTD_DIR="$ROOT/zstandard_native/src/zstd"
REF="${1:-dev}"

echo "Fetching zstd from https://github.com/facebook/zstd.git (ref: $REF)..."
TMP="$ROOT/.zstd_upstream"
rm -rf "$TMP"
git clone --depth 1 --branch "$REF" https://github.com/facebook/zstd.git "$TMP"

mkdir -p "$ZSTD_DIR"
echo "Copying lib/ into $ZSTD_DIR ..."
rsync -a --delete "$TMP/lib/" "$ZSTD_DIR/"
rm -rf "$TMP"

if [[ ! -f "$ZSTD_DIR/zstd.h" ]]; then
  echo "Error: zstd.h not found after copy."
  exit 1
fi
echo "Done. zstandard_native/src/zstd/ is now in sync with facebook/zstd @ $REF."
echo "Next: run ./scripts/sync_zstd_ios_macos.sh and optionally ./scripts/regenerate_bindings.sh"
