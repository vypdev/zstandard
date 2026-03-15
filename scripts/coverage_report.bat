@echo off
REM Generate coverage reports for zstandard packages.
REM Usage: from repo root, run: scripts\coverage_report.bat
REM Output: each package's coverage/ folder; no merge on Windows unless lcov is installed.

set ROOT=%~dp0..
cd /d "%ROOT%"

if not exist coverage mkdir coverage

for %%p in (zstandard zstandard_platform_interface zstandard_android zstandard_ios zstandard_macos zstandard_linux zstandard_windows zstandard_web) do (
  if exist "%%p" (
    echo ---- Coverage: %%p ----
    cd "%%p"
    flutter test --coverage
    cd "%ROOT%"
  )
)

if exist zstandard_cli (
  echo ---- Coverage: zstandard_cli ----
  cd zstandard_cli
  dart test --coverage=coverage
  dart run coverage:format_coverage --lcov -i coverage -o coverage/lcov.info --packages=.dart_tool/package_config.json
  cd "%ROOT%"
)

echo Coverage files are in each package's coverage\ directory.
echo For merged report, use WSL or install lcov and run scripts/coverage_report.sh
