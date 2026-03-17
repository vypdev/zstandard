#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zstandard_ios.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.cocoapods_version = '>= 1.11.0'  # for script_phase :before_headers
  s.name             = 'zstandard_ios'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # Zstd C sources: synced from zstandard_native/src/zstd/ into Classes/zstd/ by
  # scripts/sync_zstd_ios_macos.sh (repo) or script_phase (pub-cache). Must exist at pod install time so source_files glob finds them.
  s.source           = { :path => '.' }
  s.source_files =    'Classes/zstd/**/*.c', 'Classes/zstd/**/*.h', 'Classes/*.swift'
  # zstd.h includes zstd_errors.h; both must be public so the module build finds them.
  s.public_header_files = 'Classes/zstd/zstd.h', 'Classes/zstd/zstd_errors.h'

  # Run at pod install so Classes/zstd exists when CocoaPods globs source_files (repo only; from pub-cache script_phase syncs at build time).
  s.prepare_command = <<~CMD
    bash -c '[ -x "../../scripts/sync_zstd_ios_macos.sh" ] && "../../scripts/sync_zstd_ios_macos.sh" ios'
  CMD

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice. Export zstd C symbols so Dart FFI can find them.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/Classes/zstd',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'OTHER_CFLAGS' => '$(inherited) -DZSTD_STATIC_LINKING_ONLY -DZSTD_DISABLE_ASM -fvisibility=default',
    'DEAD_CODE_STRIPPING' => 'NO',
    'STRIP_INSTALLED_PRODUCT' => 'NO',
  }

  # script_phases run at BUILD time; source_files glob runs at POD INSTALL time. Sync must run
  # BEFORE Headers. 1) Repo: run sync script from ROOT. 2) Pub-cache: find zstandard_native via package_config and rsync.
  s.script_phases = [
    {
      :name => 'Sync zstd',
      :script => <<~SCRIPT,
        DEST="${PODS_TARGET_SRCROOT}/Classes/zstd"
        POD_ROOT="$(cd "${PODS_TARGET_SRCROOT}" 2>/dev/null && pwd -P)"
        [ -z "$POD_ROOT" ] && POD_ROOT="$(cd "${SRCROOT}/${PODS_TARGET_SRCROOT}" 2>/dev/null && pwd -P)"
        ROOT="${POD_ROOT:-$PODS_TARGET_SRCROOT}"
        while [ -n "$ROOT" ] && [ ! -f "$ROOT/scripts/sync_zstd_ios_macos.sh" ]; do ROOT="${ROOT%/*}"; done
        if [ -n "$ROOT" ] && [ -f "$ROOT/scripts/sync_zstd_ios_macos.sh" ]; then
          bash "$ROOT/scripts/sync_zstd_ios_macos.sh" ios
          CANONICAL="$ROOT/zstandard_ios/ios/Classes/zstd"
          if [ -d "$CANONICAL" ]; then
            REAL_DEST="$(cd "${PODS_TARGET_SRCROOT}" 2>/dev/null && pwd -P)/Classes/zstd" || REAL_DEST="$DEST"
            if [ "$(cd "$CANONICAL" 2>/dev/null && pwd -P)" != "$(cd "$REAL_DEST" 2>/dev/null && pwd -P)" ]; then
              mkdir -p "$REAL_DEST"
              rsync -a "$CANONICAL/" "$REAL_DEST/"
            fi
          fi
        else
          SRC=""
          SEARCH="$POD_ROOT"
          while [ -n "$SEARCH" ]; do
            if [ -f "$SEARCH/.dart_tool/package_config.json" ]; then
              NATIVE_ROOT=$(grep -A 2 '"name": "zstandard_native"' "$SEARCH/.dart_tool/package_config.json" 2>/dev/null | grep '"rootUri"' | sed -n 's/.*"rootUri": "file:\\/\\/\\([^"]*\\)".*/\1/p' | head -1)
              if [ -n "$NATIVE_ROOT" ] && [ -d "$NATIVE_ROOT/src/zstd" ] && [ -f "$NATIVE_ROOT/src/zstd/zstd.h" ]; then
                SRC="$NATIVE_ROOT/src/zstd"
                break
              fi
            fi
            SEARCH="${SEARCH%/*}"
            [ "$SEARCH" = "${SEARCH%/*}" ] && break
          done
          if [ -n "$SRC" ]; then
            mkdir -p "$DEST"
            rsync -a "$SRC/" "$DEST/"
            if [ -f "$DEST/module.modulemap" ]; then rm -f "$DEST/module.modulemap"; fi
          fi
        fi
      SCRIPT
      :execution_position => :before_headers,
      :output_files => ['$(PODS_TARGET_SRCROOT)/Classes/zstd/zstd.h']
    },
    { :name => 'Remove synced zstd', :script => 'rm -rf "${PODS_TARGET_SRCROOT}/Classes/zstd"', :execution_position => :any }
  ]

  s.swift_version = '5.0'
end
