#!/usr/bin/env bash
# Regenerate FFI bindings from the C headers in each platform package.
# Run this after updating the zstd C source (e.g. after sync_zstd_ios_macos.sh).
#
# Usage: from repo root, run: ./scripts/regenerate_bindings.sh
#
# Requires: dart run ffigen (and LLVM/clang for ffigen). Do not modify the
# native zstd C code by hand; update source then sync, then run this script.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PACKAGES=(
  "zstandard_android"
  "zstandard_ios"
  "zstandard_macos"
  "zstandard_linux"
  "zstandard_windows"
  "zstandard_cli"
)

echo "Regenerating FFI bindings (ffigen) for all platform packages..."
for pkg in "${PACKAGES[@]}"; do
  dir="$ROOT/$pkg"
  if [[ -f "$dir/ffigen.yaml" ]]; then
    echo "  $pkg"
    (cd "$dir" && dart run ffigen --config ffigen.yaml)
  else
    echo "  $pkg (no ffigen.yaml, skip)"
  fi
done
echo "Done. Commit any changed *_bindings_generated.dart files."
