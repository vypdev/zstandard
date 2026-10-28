#!/usr/bin/env bash
# Shared private Linux dependencies for platform CI and project verification.
set -euo pipefail
command -v apt-get >/dev/null
command -v apt-cache >/dev/null
command -v dpkg-query >/dev/null
packages=(build-essential clang cmake coreutils ninja-build pkg-config curl unzip)
browser_missing=()
if [[ "$ANDROID" == 'true' ]]; then
  packages+=(libdbus-1-3 libfontconfig1 libgl1 libnss3 libpulse0 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxi6 libxrandr2 libxrender1 libxtst6)
fi
if [[ "$BROWSER" == 'true' ]]; then
  packages+=(ca-certificates libdbus-1-3 libdrm2 libgbm1 libnspr4 libnss3 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 libxkbcommon0 libxrandr2)
  # Ubuntu/Debian releases before the time64 transition use the base
  # names. Reuse installed variants or resolve against private indexes.
  for legacy in libasound2 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libcups2; do
    selected=''
    for candidate in "${legacy}t64" "$legacy"; do
      if [[ "$(dpkg-query -W -f='${Status}' "$candidate" 2>/dev/null || true)" == 'install ok installed' ]]; then
        selected="$candidate"
        break
      fi
    done
    if [[ -n "$selected" ]]; then packages+=("$selected"); else browser_missing+=("$legacy"); fi
  done
fi
if [[ "$DESKTOP" == 'true' ]]; then packages+=(libgtk-3-dev xvfb); fi
if [[ "$COVERAGE" == 'true' ]]; then packages+=(bc lcov); fi
if [[ "$ARM64" == 'true' ]]; then packages+=(gcc-aarch64-linux-gnu g++-aarch64-linux-gnu); fi
missing=()
for package in "${packages[@]}"; do
  if [[ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)" != 'install ok installed' ]]; then
    missing+=("$package")
  fi
done
if [[ "${#missing[@]}" -eq 0 && "${#browser_missing[@]}" -eq 0 ]]; then
  echo 'All selected Linux prerequisites are already installed.'
  exit 0
fi
state_root="${ZSTANDARD_LINUX_STATE_ROOT:-$RUNNER_TEMP}"
state="$(mktemp -d "$state_root/zstandard-linux-tools.XXXXXX")"
mkdir -p "$state/apt/lists/partial" "$state/packages/partial" "$state/prefix"
cp /var/lib/dpkg/status "$state/apt/status"
apt_options=(-o "Dir::State::status=$state/apt/status" -o "Dir::State::Lists=$state/apt/lists" -o "Dir::Cache::archives=$state/packages" -o "Dir::Cache::pkgcache=$state/apt/pkgcache.bin" -o "Dir::Cache::srcpkgcache=$state/apt/srcpkgcache.bin" -o Acquire::Retries=0 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30)
apt-get "${apt_options[@]}" update
for legacy in "${browser_missing[@]}"; do
  apt_candidate="$(LC_ALL=C apt-cache "${apt_options[@]}" policy "${legacy}t64" | sed -n 's/^  Candidate: //p')"
  if [[ -n "$apt_candidate" && "$apt_candidate" != '(none)' ]]; then
    missing+=("${legacy}t64")
  else
    missing+=("$legacy")
  fi
done
apt-get "${apt_options[@]}" --download-only --assume-yes --no-install-recommends install "${missing[@]}"
for package in "$state/packages/"*.deb; do
  [[ -f "$package" ]] || continue
  dpkg-deb --extract "$package" "$state/prefix"
done
prefix="$state/prefix"
# pkg-config needs both extracted and preinstalled headers/libraries.
# Fill only missing private paths with links; never traverse a target link.
overlay_system() {
  local source="$1" target="$2" child destination
  [[ -d "$source" && ! -L "$source" && ! -L "$target" ]] || return 0
  mkdir -p "$target"
  for child in "$source/"*; do
    [[ -e "$child" || -L "$child" ]] || continue
    destination="$target/${child##*/}"
    if [[ -L "$destination" ]]; then
      continue
    elif [[ -d "$destination" && -d "$child" && ! -L "$child" ]]; then
      overlay_system "$child" "$destination"
    elif [[ ! -e "$destination" ]]; then
      ln -s "$child" "$destination"
    fi
  done
}
case "$(dpkg --print-architecture)" in
  amd64) multiarch=x86_64-linux-gnu ;;
  arm64) multiarch=aarch64-linux-gnu ;;
  *) echo 'Unsupported Linux runner architecture.' >&2; exit 1 ;;
esac
overlay_system /usr/include "$prefix/usr/include"
overlay_system "/usr/lib/$multiarch" "$prefix/usr/lib/$multiarch"
overlay_system /usr/share/pkgconfig "$prefix/usr/share/pkgconfig"
for directory in lib lib64 bin sbin; do
  if [[ ! -e "$prefix/$directory" && ! -L "$prefix/$directory" ]]; then
    ln -s "usr/$directory" "$prefix/$directory"
  fi
done
overlay_system "/lib/$multiarch" "$prefix/lib/$multiarch"
# GNU linker scripts carry absolute development-library paths. Relocate
# only regular private scripts; shared host libraries remain read-only.
while IFS= read -r -d '' linker_script; do
  if grep -Iq '^/\* GNU ld script' "$linker_script"; then
    ZSTANDARD_LINUX_PREFIX="$prefix" /usr/bin/perl -0pi -e '
      s{(?<![\w"])(/[A-Za-z0-9_./+-]+)}{
        my $path = $ENV{"ZSTANDARD_LINUX_PREFIX"} . $1;
        if (-e $path) {
          $path =~ s/([\\"])/\\$1/g;
          qq("$path")
        } else { $1 }
      }ge
    ' "$linker_script"
  fi
done < <(find "$prefix" -type f -name '*.so' -print0)
lcov_module="$prefix/usr/lib/lcov/lcovutil.pm"
if [[ -f "$lcov_module" && ! -L "$lcov_module" ]]; then
  sed -i 's|^our \$tool_dir.*;|our $tool_dir = $ENV{"ZSTANDARD_LCOV_BIN"} // "/usr/bin";|' "$lcov_module"
fi
libraries="$prefix/usr/lib/$multiarch:$prefix/usr/lib:$prefix/lib/$multiarch:$prefix/lib"
for directory in "$prefix/usr/lib/"llvm*/lib; do
  if [[ -d "$directory" ]]; then libraries="$libraries:$directory"; fi
done
perl_libraries="$prefix/usr/lib/lcov:$prefix/usr/share/perl5"
for directory in "$prefix/usr/share/perl/"* "$prefix/usr/lib/$multiarch/perl5/"* "$prefix/usr/lib/$multiarch/perl/"*; do
  if [[ -d "$directory" ]]; then perl_libraries="$perl_libraries:$directory"; fi
done
{
  printf 'ZSTANDARD_LCOV_BIN=%s/usr/bin\n' "$prefix"
  printf 'PERL5LIB=%s%s\n' "$perl_libraries" "${PERL5LIB:+:$PERL5LIB}"
  printf 'LD_LIBRARY_PATH=%s%s\n' "$libraries" "${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  if [[ "$ANDROID" != 'true' ]]; then
    printf 'LIBRARY_PATH=%s%s\n' "$libraries" "${LIBRARY_PATH:+:$LIBRARY_PATH}"
    printf 'CPATH=%s/usr/include:%s/usr/include/%s%s\n' "$prefix" "$prefix" "$multiarch" "${CPATH:+:$CPATH}"
    printf 'PKG_CONFIG_PATH=%s/usr/lib/%s/pkgconfig:%s/usr/share/pkgconfig%s\n' "$prefix" "$multiarch" "$prefix" "${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    printf 'PKG_CONFIG_SYSROOT_DIR=%s\n' "$prefix"
    printf 'CMAKE_PREFIX_PATH=%s/usr%s\n' "$prefix" "${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
  fi
} >> "$GITHUB_ENV"
printf '%s/usr/bin\n' "$prefix" >> "$GITHUB_PATH"
