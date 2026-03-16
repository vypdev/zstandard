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

echo Running Windows integration tests...
cd zstandard_windows\example
flutter test integration_test/ -d windows
set EXIT_CODE=%errorlevel%
cd /d "%ROOT%"

if %EXIT_CODE% equ 0 (
  echo Windows integration tests passed.
) else (
  echo Windows integration tests failed.
)
exit /b %EXIT_CODE%
