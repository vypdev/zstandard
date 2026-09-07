#!/usr/bin/env bash
# Create package-local dependency overrides for monorepo validation.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="${1:-}"
EXTERNAL_NATIVE="${2:-}"

package_native='../zstandard_native'
example_native='../../zstandard_native'
if [[ -n "$EXTERNAL_NATIVE" ]]; then
  package_native="$EXTERNAL_NATIVE"
  example_native="$EXTERNAL_NATIVE"
fi

case "$PACKAGE" in
  zstandard_native|zstandard_platform_interface)
    exit 0
    ;;
  zstandard_cli)
    printf '%s\n' \
      'dependency_overrides:' \
      '  zstandard_native:' \
      "    path: $package_native" \
      > "$ROOT/$PACKAGE/pubspec_overrides.yaml"
    ;;
  zstandard_android|zstandard_ios|zstandard_linux|zstandard_macos|zstandard_web|zstandard_windows)
    printf '%s\n' \
      'dependency_overrides:' \
      '  zstandard_native:' \
      "    path: $package_native" \
      '  zstandard_platform_interface:' \
      '    path: ../zstandard_platform_interface' \
      > "$ROOT/$PACKAGE/pubspec_overrides.yaml"
    if [[ -d "$ROOT/$PACKAGE/example" ]]; then
      printf '%s\n' \
        'dependency_overrides:' \
        '  zstandard_native:' \
        "    path: $example_native" \
        '  zstandard_platform_interface:' \
        '    path: ../../zstandard_platform_interface' \
        > "$ROOT/$PACKAGE/example/pubspec_overrides.yaml"
    fi
    if [[ "$PACKAGE" == zstandard_android && -d "$ROOT/$PACKAGE/example_legacy" ]]; then
      printf '%s\n' \
        'dependency_overrides:' \
        '  zstandard_native:' \
        "    path: $example_native" \
        '  zstandard_platform_interface:' \
        '    path: ../../zstandard_platform_interface' \
        > "$ROOT/$PACKAGE/example_legacy/pubspec_overrides.yaml"
    fi
    ;;
  zstandard)
    printf '%s\n' \
      'dependency_overrides:' \
      '  zstandard_android:' \
      '    path: ../zstandard_android' \
      '  zstandard_ios:' \
      '    path: ../zstandard_ios' \
      '  zstandard_linux:' \
      '    path: ../zstandard_linux' \
      '  zstandard_macos:' \
      '    path: ../zstandard_macos' \
      '  zstandard_native:' \
      '    path: ../zstandard_native' \
      '  zstandard_platform_interface:' \
      '    path: ../zstandard_platform_interface' \
      '  zstandard_web:' \
      '    path: ../zstandard_web' \
      '  zstandard_windows:' \
      '    path: ../zstandard_windows' \
      > "$ROOT/$PACKAGE/pubspec_overrides.yaml"
    ;;
  *)
    echo "Unsupported package: $PACKAGE" >&2
    exit 2
    ;;
esac
