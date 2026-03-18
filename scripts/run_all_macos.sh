#!/usr/bin/env bash
# Run all preparación, build and test steps that are runnable on macOS, in sequence.
# Usage: from repo root, run: ./scripts/run_all_macos.sh
#
# Steps:
#   1. Sync/update zstd library (iOS + macOS)
#   2. Regenerate FFI bindings
#   3. Build Android (example app APK; builds plugin native lib via Gradle)
#   4. Build CLI (macOS dylibs for zstandard_cli)
#   5. Build iOS (example app)
#   6. Build web (example app)
#   7. Build macOS (example app)
#   8. Test Android (zstandard_android)
#   9. Test CLI (zstandard_cli)
#  10. Test iOS (zstandard_ios)
#  11. Test web (zstandard_web)
#  12. Test macOS (zstandard_macos)
#
# Requires: macOS, Flutter SDK, Dart SDK, Xcode, CocoaPods, Android SDK/NDK (for Android),
#           CMake (for CLI build). Stops on first failure (set -e).

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This script is intended for macOS."
  exit 1
fi

EXAMPLE="$ROOT/zstandard/example"

step() {
  echo ""
  echo "========== $1 =========="
}

# 1. Preparar/actualizar librería zstd (iOS y macOS)
step "1/12 — Sync zstd (iOS + macOS)"
bash "$ROOT/zstandard_ios/scripts/sync_zstd.sh"
bash "$ROOT/zstandard_macos/scripts/sync_zstd.sh"

# 2. Actualizar bindings
step "2/12 — Regenerate bindings"
./scripts/regenerate_bindings.sh

# 3. Compilar Android (example app; el plugin no tiene gradlew, se compila con la app)
step "3/12 — Build Android"
cd "$EXAMPLE" && flutter build apk && cd "$ROOT"

# 4. Compilar CLI (dylibs macOS para zstandard_cli)
step "4/12 — Build CLI (macOS native libs)"
./scripts/build_macos.sh

# 5. Compilar iOS (example app)
step "5/12 — Build iOS"
cd "$EXAMPLE/ios" && pod install && cd "$ROOT"
cd "$EXAMPLE" && flutter build ios --simulator --no-codesign && cd "$ROOT"

# 6. Compilar web
step "6/12 — Build web"
cd "$EXAMPLE" && flutter build web && cd "$ROOT"

# 7. Compilar macOS (example app)
step "7/12 — Build macOS"
cd "$EXAMPLE" && flutter build macos && cd "$ROOT"

# 8. Test Android
step "8/12 — Test Android"
cd "$ROOT/zstandard_android" && flutter test && cd "$ROOT"

# 9. Test CLI
step "9/12 — Test CLI"
cd "$ROOT/zstandard_cli" && dart test && cd "$ROOT"

# 10. Test iOS
step "10/12 — Test iOS"
cd "$ROOT/zstandard_ios" && flutter test && cd "$ROOT"

# 11. Test web
step "11/12 — Test web"
cd "$ROOT/zstandard_web" && flutter test && cd "$ROOT"

# 12. Test macOS
step "12/12 — Test macOS"
cd "$ROOT/zstandard_macos" && flutter test && cd "$ROOT"

echo ""
echo "========== All steps completed successfully =========="
