#!/usr/bin/env bash
# Regenerate FFI bindings from the zstd C headers in zstandard_native.
# Run this after updating the zstd C source (e.g. after scripts/update_zstd.sh).
#
# Usage: from repo root, run: ./scripts/regenerate_bindings.sh
#
# Requires: dart run ffigen (and LLVM/clang for ffigen). Bindings are generated
# in zstandard_native/lib/zstandard_native_bindings.dart and used by all platform packages.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Regenerating FFI bindings (ffigen) in zstandard_native..."
(cd "$ROOT/zstandard_native" && dart run ffigen --config ffigen.yaml)
echo "Done. Commit any changed zstandard_native/lib/zstandard_native_bindings.dart"
