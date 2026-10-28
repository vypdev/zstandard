#!/usr/bin/env bash
# Run all unit tests across zstandard packages.
# Usage: from repo root, run: ./scripts/test_all.sh
# Requires: Python 3, Flutter/Dart and the platform's native build tools.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "$ROOT/scripts/run_unit_tests.py"
