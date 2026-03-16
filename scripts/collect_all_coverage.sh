#!/usr/bin/env bash
# Collect coverage from all packages into a single directory for reporting.
# Run from repo root. Creates coverage/ with lcov.info from each package.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p coverage_all

for pkg in zstandard zstandard_platform_interface zstandard_android zstandard_ios zstandard_macos zstandard_linux zstandard_windows zstandard_web; do
  if [ ! -d "$pkg" ]; then continue; fi
  echo "Collecting coverage from $pkg..."
  (cd "$pkg" && flutter test --coverage 2>/dev/null) || true
  if [ -f "$pkg/coverage/lcov.info" ]; then
    cp "$pkg/coverage/lcov.info" "coverage_all/${pkg}.lcov.info" 2>/dev/null || true
  fi
done

if [ -d "zstandard_cli" ]; then
  (cd zstandard_cli && dart test --coverage=coverage 2>/dev/null) || true
  (cd zstandard_cli && dart run coverage:format_coverage --lcov -i coverage -o coverage/lcov.info --packages=.dart_tool/package_config.json 2>/dev/null) || true
  if [ -f "zstandard_cli/coverage/lcov.info" ]; then
    cp zstandard_cli/coverage/lcov.info coverage_all/zstandard_cli.lcov.info 2>/dev/null || true
  fi
fi

echo "Coverage files in coverage_all/"
ls -la coverage_all/ 2>/dev/null || true
