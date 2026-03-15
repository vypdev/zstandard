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

  # Zstd C sources: synced from repo root zstd/ into Classes/zstd/ by
  # scripts/sync_zstd_ios_macos.sh. Must exist at pod install time so source_files glob finds them.
  s.source           = { :path => '.' }
  s.source_files =    'Classes/zstd/**/*.c', 'Classes/zstd/**/*.h', 'Classes/*.swift'
  # zstd.h includes zstd_errors.h; both must be public so the module build finds them.
  s.public_header_files = 'Classes/zstd/zstd.h', 'Classes/zstd/zstd_errors.h'

  # Run at pod install so Classes/zstd exists when CocoaPods globs source_files (path pods only).
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
  # BEFORE Headers (Copy Headers reads Classes/zstd). Use :before_headers; find repo root by
  # walking up from PODS_TARGET_SRCROOT (e.g. Flutter .symlinks). Remove uses :any so it runs last.
  s.script_phases = [
    {
      :name => 'Sync zstd',
      :script => <<~SCRIPT,
        POD_ROOT="$(cd "${PODS_TARGET_SRCROOT}" 2>/dev/null && pwd -P)"
        [ -z "$POD_ROOT" ] && POD_ROOT="$(cd "${SRCROOT}/${PODS_TARGET_SRCROOT}" 2>/dev/null && pwd -P)"
        ROOT="${POD_ROOT:-$PODS_TARGET_SRCROOT}"
        while [ -n "$ROOT" ] && [ ! -f "$ROOT/scripts/sync_zstd_ios_macos.sh" ]; do ROOT="${ROOT%/*}"; done
        if [ -n "$ROOT" ] && [ -f "$ROOT/scripts/sync_zstd_ios_macos.sh" ]; then
          bash "$ROOT/scripts/sync_zstd_ios_macos.sh" ios
          CANONICAL="$ROOT/zstandard_ios/ios/Classes/zstd"
          DEST="${PODS_TARGET_SRCROOT}/Classes/zstd"
          if [ -d "$CANONICAL" ]; then
            REAL_DEST="$(cd "${PODS_TARGET_SRCROOT}" 2>/dev/null && pwd -P)/Classes/zstd" || REAL_DEST="$DEST"
            if [ "$(cd "$CANONICAL" 2>/dev/null && pwd -P)" != "$(cd "$REAL_DEST" 2>/dev/null && pwd -P)" ]; then
              mkdir -p "$REAL_DEST"
              rsync -a "$CANONICAL/" "$REAL_DEST/"
            fi
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
