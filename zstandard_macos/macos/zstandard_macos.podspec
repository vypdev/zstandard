#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zstandard_macos.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.cocoapods_version = '>= 1.11.0'  # for script_phase :before_headers
  s.name             = 'zstandard_macos'
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
  s.source_files     = 'Classes/zstandard_macos.c', 'Classes/**/*.swift',
                       'Classes/zstd/common/*.c', 'Classes/zstd/common/*.h',
                       'Classes/zstd/compress/*.c', 'Classes/zstd/compress/*.h',
                       'Classes/zstd/decompress/*.c', 'Classes/zstd/decompress/*.h',
                       'Classes/zstd/decompress/*.S',
                       'Classes/zstd/dictBuilder/*.c', 'Classes/zstd/dictBuilder/*.h',
                       'Classes/zstd/legacy/*.c', 'Classes/zstd/legacy/*.h',
                       'Classes/zstd/*.h'
  s.private_header_files = 'Classes/zstd/**/*.h'

  # Run at pod install so Classes/zstd exists when CocoaPods globs source_files (path pods only).
  s.prepare_command = <<~CMD
    bash -c '[ -x "../../scripts/sync_zstd_ios_macos.sh" ] && "../../scripts/sync_zstd_ios_macos.sh" macos'
  CMD

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/Classes/zstd',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'OTHER_CFLAGS' => '$(inherited) -DZSTD_STATIC_LINKING_ONLY',
  }

  # script_phases run at BUILD time; source_files glob runs at POD INSTALL time. So if Classes/zstd
  # doesn't exist at pod install (e.g. path pod, prepare_command not run), the target gets no zstd
  # files. before_compile sync ensures latest zstd at build; after_compile removes the copy.
  # Sync must run BEFORE Headers (Copy Headers reads Classes/zstd). CocoaPods runs Headers before
  # Compile, so we use :before_headers so the sync runs first. Find repo root by walking up from
  # the resolved pod path; use SRCROOT when PODS_TARGET_SRCROOT is relative (e.g. Flutter .symlinks).
  s.script_phases = [
    {
      :name => 'Sync zstd',
      :script => <<~SCRIPT,
        POD_ROOT="$(cd "${PODS_TARGET_SRCROOT}" 2>/dev/null && pwd -P)"
        [ -z "$POD_ROOT" ] && POD_ROOT="$(cd "${SRCROOT}/${PODS_TARGET_SRCROOT}" 2>/dev/null && pwd -P)"
        ROOT="${POD_ROOT:-$PODS_TARGET_SRCROOT}"
        while [ -n "$ROOT" ] && [ ! -f "$ROOT/scripts/sync_zstd_ios_macos.sh" ]; do ROOT="${ROOT%/*}"; done
        if [ -n "$ROOT" ] && [ -f "$ROOT/scripts/sync_zstd_ios_macos.sh" ]; then
          bash "$ROOT/scripts/sync_zstd_ios_macos.sh" macos
          CANONICAL="$ROOT/zstandard_macos/macos/Classes/zstd"
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
      :execution_position => :before_headers
    },
    { :name => 'Remove synced zstd', :script => 'rm -rf "${PODS_TARGET_SRCROOT}/Classes/zstd"', :execution_position => :after_compile }
  ]

  s.swift_version = '5.0'
end
