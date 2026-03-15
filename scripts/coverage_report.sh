#!/usr/bin/env bash
# Generate combined coverage report for zstandard packages.
# Usage: from repo root, run: ./scripts/coverage_report.sh
# Output: coverage/ directory with lcov.info and optionally HTML report.
# Requires: Flutter SDK, Dart SDK, and (for HTML) lcov or genhtml.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p coverage
COVERAGE_DIR="$ROOT/coverage"
LCOV_ARGS=()

# Run tests with coverage per package and collect lcov
for pkg in zstandard zstandard_platform_interface zstandard_android zstandard_ios zstandard_macos zstandard_linux zstandard_windows zstandard_web; do
  if [[ ! -d "$pkg" ]]; then continue; fi
  echo "---- Coverage: $pkg ----"
  (cd "$pkg" && flutter test --coverage 2>/dev/null) || true
  if [[ -f "$pkg/coverage/lcov.info" ]]; then
    LCOV_ARGS+=("--add-tracefile" "$pkg/coverage/lcov.info")
  fi
done

# CLI: dart test --coverage then format to lcov
if [[ -d "zstandard_cli" ]]; then
  echo "---- Coverage: zstandard_cli ----"
  (cd zstandard_cli && dart test --coverage=coverage 2>/dev/null && dart run coverage:format_coverage --lcov -i coverage -o coverage/lcov.info --packages=.dart_tool/package_config.json 2>/dev/null) || true
  if [[ -f "zstandard_cli/coverage/lcov.info" ]]; then
    LCOV_ARGS+=("--add-tracefile" "zstandard_cli/coverage/lcov.info")
  fi
fi

# Merge all lcov files if we have any
if [[ ${#LCOV_ARGS[@]} -gt 0 ]]; then
  if command -v lcov >/dev/null 2>&1; then
    lcov "${LCOV_ARGS[@]}" --output-file "$COVERAGE_DIR/lcov.info" --ignore-errors source,gcov
    echo "Merged lcov written to $COVERAGE_DIR/lcov.info"
    if command -v genhtml >/dev/null 2>&1; then
      genhtml "$COVERAGE_DIR/lcov.info" -o "$COVERAGE_DIR/html" --ignore-errors source
      echo "HTML report: $COVERAGE_DIR/html/index.html"
    else
      echo "Install lcov (genhtml) for HTML report."
    fi
  else
    echo "Install lcov to merge coverage. Per-package coverage is in each package's coverage/ directory."
  fi
else
  echo "No coverage files generated. Run tests with --coverage in each package first."
fi
