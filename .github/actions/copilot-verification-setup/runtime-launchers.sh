#!/usr/bin/env bash
# Copilot forwards validated PATH entries; keep native tool configuration there.
set -euo pipefail

runtime_bin="$HOME/.zstandard-verification-runtime/bin"
mkdir -p "$runtime_bin"
for tool in flutter dart; do
  executable="$(command -v "$tool")"
  test -x "$executable"
  {
    printf '#!/usr/bin/env bash\nset -euo pipefail\n'
    for setting in CPATH LIBRARY_PATH PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR CMAKE_PREFIX_PATH PUB_CACHE XDG_CONFIG_HOME; do
      value="${!setting-}"
      if [[ -n "$value" ]]; then
        printf 'export %s=%q\n' "$setting" "$value"
      fi
    done
    # The verifier may add the freshly built test plugin to its own search path.
    if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
      printf 'export LD_LIBRARY_PATH=%q"${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\n' "$LD_LIBRARY_PATH"
    fi
    printf 'exec %q "$@"\n' "$executable"
  } > "$runtime_bin/$tool"
  chmod 700 "$runtime_bin/$tool"
done
printf '%s\n' "$runtime_bin" >> "$GITHUB_PATH"
