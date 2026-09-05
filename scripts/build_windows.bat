@echo off
REM Build Windows precompiled zstd libraries for zstandard_cli (x64 and ARM64).
REM Usage: from repo root, run: scripts\build_windows.bat
REM Requires: CMake and a Visual Studio installation with the C++ workload.

set ROOT=%~dp0..
set CLI=%ROOT%\zstandard_cli
set BIN=%CLI%\lib\src\bin
set ZSTD_SRC=%ROOT%\zstandard_native\src\zstd

if not exist "%BIN%" mkdir "%BIN%"
if not exist "%ZSTD_SRC%\zstd.h" (
  echo Canonical zstd source not found at "%ZSTD_SRC%".
  echo Run scripts\update_zstd.sh from the repository root first.
  exit /b 1
)
echo Using canonical zstd source from "%ZSTD_SRC%".

for /f "usebackq delims=" %%G in (`powershell -NoProfile -Command "$g = @(cmake --help ^| Select-String -AllMatches -Pattern 'Visual Studio \d+ \d{4}').Matches ^| ForEach-Object Value ^| Sort-Object -Unique ^| Sort-Object { [int](($_ -split ' ')[-1]) } -Descending ^| Select-Object -First 1; if ($g) { $g }"`) do if not defined GENERATOR set GENERATOR=%%G
if not defined GENERATOR (
  echo No Visual Studio CMake generator was found.
  exit /b 1
)
echo Using CMake generator "%GENERATOR%".

echo Building Windows x64...
cd /d "%CLI%\builders\windows_x64"
if exist build rmdir /S /Q build
cmake -S "%CLI%\builders\windows_x64" -B "%CLI%\builders\windows_x64\build" -G "%GENERATOR%" -A x64
cmake --build "%CLI%\builders\windows_x64\build" --config Release
move "%CLI%\builders\windows_x64\build\Release\zstandard_windows.dll" "%BIN%\zstandard_windows_x64.dll"
rmdir /S /Q "%CLI%\builders\windows_x64\build"

echo Building Windows ARM64...
cd /d "%CLI%\builders\windows_arm"
if exist build rmdir /S /Q build
cmake -S "%CLI%\builders\windows_arm" -B "%CLI%\builders\windows_arm\build" -G "%GENERATOR%" -A ARM64
cmake --build "%CLI%\builders\windows_arm\build" --config Release
move "%CLI%\builders\windows_arm\build\Release\zstandard_windows.dll" "%BIN%\zstandard_windows_arm64.dll"
rmdir /S /Q "%CLI%\builders\windows_arm\build"

echo Done. Outputs in %BIN%
dir "%BIN%\*.dll"
