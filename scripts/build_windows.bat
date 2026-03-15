@echo off
REM Build Windows precompiled zstd libraries for zstandard_cli (x64 and ARM64).
REM Usage: from repo root, run: scripts\build_windows.bat
REM Requires: CMake, Visual Studio 2022, git.

set ROOT=%~dp0..
set CLI=%ROOT%\zstandard_cli
set BIN=%CLI%\lib\src\bin

if not exist "%BIN%" mkdir "%BIN%"

echo Fetching zstd sources into zstandard_cli/src...
cd /d "%CLI%"
if exist "src\zstd.h" (
  echo Using existing zstandard_cli/src.
) else (
  if exist zstd rmdir /S /Q zstd
  if exist src rmdir /S /Q src
  git clone --depth 1 https://github.com/facebook/zstd.git
  mkdir src
  xcopy zstd\lib src\ /E /I
  rmdir /S /Q zstd
)

echo Building Windows x64...
cd /d "%CLI%\builders\windows_x64"
if exist build rmdir /S /Q build
mkdir build
cd build
cmake -G "Visual Studio 17 2022" -A x64 ..
cmake --build . --config Release
cd Release
move zstandard_windows.dll "%BIN%\zstandard_windows_x64.dll"
cd ..\..
rmdir /S /Q build

echo Building Windows ARM64...
cd /d "%CLI%\builders\windows_arm"
if exist build rmdir /S /Q build
mkdir build
cd build
cmake -G "Visual Studio 17 2022" -A ARM64 ..
cmake --build . --config Release
cd Release
move zstandard_windows.dll "%BIN%\zstandard_windows_arm64.dll"
cd ..\..
rmdir /S /Q build

echo Done. Outputs in %BIN%
dir "%BIN%\*.dll"
