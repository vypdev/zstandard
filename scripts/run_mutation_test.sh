#!/usr/bin/env bash
# Run mutation testing on a single package or all packages.
# Usage: ./scripts/run_mutation_test.sh [package_name]
#   If package_name is omitted, runs on zstandard only (main package).
#   Use "all" to run on all packages (takes a long time).
# Requires: mutation_test dev_dependency in each package.
# Config: mutation_test_config.xml at repo root (Flutter) or in zstandard_cli (dart test).

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

run_mutation() {
  local dir="$1"
  local config="$2"
  if [[ ! -d "$dir" ]]; then
    echo "Skip $dir (not found)"
    return 0
  fi
  echo "---- Mutation testing $dir ----"
  if (cd "$dir" && dart run mutation_test "$config"); then
    echo "OK $dir"
    return 0
  else
    echo "FAILED $dir (mutation score below threshold or error)"
    return 1
  fi
}

PKG="${1:-zstandard}"

if [[ "$PKG" == "all" ]]; then
  FAILED=0
  for pkg in zstandard zstandard_platform_interface zstandard_android zstandard_ios zstandard_macos zstandard_linux zstandard_windows zstandard_web; do
    run_mutation "$pkg" "../mutation_test_config.xml" || FAILED=1
  done
  run_mutation "zstandard_cli" "mutation_test_config.xml" || FAILED=1
  exit $FAILED
else
  if [[ "$PKG" == "zstandard_cli" ]]; then
    run_mutation "zstandard_cli" "mutation_test_config.xml"
  else
    run_mutation "$PKG" "../mutation_test_config.xml"
  fi
fi
