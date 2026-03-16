#!/usr/bin/env bash
# Run the zstandard_cli compression benchmark.
# Usage: from repo root, run: ./scripts/run_benchmark.sh
# Use output as baseline for regression detection.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/zstandard_cli"
dart run benchmark/compression_benchmark.dart
