#!/usr/bin/env bash
# Create package-local dependency overrides for monorepo validation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec dart "$SCRIPT_DIR/create_local_overrides.dart" "$@"
