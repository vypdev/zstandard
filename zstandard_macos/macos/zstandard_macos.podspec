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

  # Zstd C sources: synced from zstandard_native/src/zstd/ into Classes/zstd/ by
  # scripts/sync_zstd.sh (in this plugin). Must exist at pod install time so source_files glob finds them.
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

  # Run at pod install so Classes/zstd exists when CocoaPods globs source_files.
  s.prepare_command = "bash '../scripts/sync_zstd.sh'"

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  # Export zstd C symbols so Dart FFI (DynamicLibrary.lookup) can find them in the framework.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/Classes/zstd',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'OTHER_CFLAGS' => '$(inherited) -DZSTD_STATIC_LINKING_ONLY -fvisibility=default',
    'DEAD_CODE_STRIPPING' => 'NO',
    'STRIP_INSTALLED_PRODUCT' => 'NO',
  }

  # script_phases run at BUILD time. Sync runs before Headers via script bundled in this plugin.
  s.script_phases = [
    {
      :name => 'Sync zstd',
      :script => <<~SCRIPT,
        PLUGIN_ROOT="$(dirname "${PODS_TARGET_SRCROOT}")"
        if [ -f "$PLUGIN_ROOT/scripts/sync_zstd.sh" ]; then
          bash "$PLUGIN_ROOT/scripts/sync_zstd.sh"
        else
          echo "Error: scripts/sync_zstd.sh not found in zstandard_macos plugin"
          exit 1
        fi
      SCRIPT
      :execution_position => :before_headers,
      :output_files => ['$(PODS_TARGET_SRCROOT)/Classes/zstd/zstd.h']
    },
    { :name => 'Remove synced zstd', :script => 'rm -rf "${PODS_TARGET_SRCROOT}/Classes/zstd"', :execution_position => :any }
  ]

  s.swift_version = '5.0'
end
