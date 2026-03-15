#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zstandard_macos.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
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
  # scripts/sync_zstd_ios_macos.sh. Exclude deprecated/ (zbuff); include legacy.
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
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/Classes/zstd',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'OTHER_CFLAGS' => '$(inherited) -DZSTD_STATIC_LINKING_ONLY',
  }

  # Remove synced zstd copy after compile so Classes/zstd is not left on disk.
  s.script_phases = [
    { :name => 'Remove synced zstd', :script => 'rm -rf "${PODS_TARGET_SRCROOT}/Classes/zstd"', :execution_position => :after_compile }
  ]

  s.swift_version = '5.0'
end
