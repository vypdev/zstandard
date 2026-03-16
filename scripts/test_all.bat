@echo off
REM Run all unit tests across zstandard packages.
REM Usage: from repo root, run: scripts\test_all.bat
REM Requires: Flutter SDK (for Flutter packages), Dart SDK (for CLI).

set ROOT=%~dp0..
cd /d "%ROOT%"
set FAILED=0

for %%p in (zstandard zstandard_platform_interface zstandard_android zstandard_ios zstandard_macos zstandard_linux zstandard_windows zstandard_web) do (
  if exist "%%p" (
    echo ---- Testing %%p ----
    cd "%%p"
    flutter test
    if errorlevel 1 set FAILED=1
    cd "%ROOT%"
  )
)

if exist zstandard_cli (
  echo ---- Testing zstandard_cli ----
  cd zstandard_cli
  dart test
  if errorlevel 1 set FAILED=1
  cd "%ROOT%"
)

if %FAILED% neq 0 (
  echo One or more packages had test failures.
  exit /b 1
)
echo All tests passed.
