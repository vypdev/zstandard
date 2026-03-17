@echo off
REM Run Windows integration tests on the current machine.
REM Usage: from repo root, scripts\test_windows_integration.bat
REM Requires: Windows, Flutter SDK with Windows desktop support.

setlocal
set ROOT=%~dp0..
cd /d "%ROOT%"

where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter not found on PATH.
  exit /b 1
)

cd zstandard_windows\example
call flutter clean
call flutter pub get
echo Running Windows integration tests...
call flutter test integration_test\windows_integration_test.dart -d windows
set EXIT_CODE=%errorlevel%
cd /d "%ROOT%"

if %EXIT_CODE% equ 0 (
  echo.
  echo Windows integration tests passed.
) else (
  echo.
  echo Windows integration tests failed.
)
exit /b %EXIT_CODE%
