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

  # Zstd C sources live at repo root ../../zstd (single source of truth).
  # Exclude deprecated/ (zbuff) to avoid module/macro issues; include legacy for decompress.
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/zstandard_macos.c', 'Classes/**/*.swift',
                       '../../zstd/common/*.c', '../../zstd/common/*.h',
                       '../../zstd/compress/*.c', '../../zstd/compress/*.h',
                       '../../zstd/decompress/*.c', '../../zstd/decompress/*.h',
                       '../../zstd/dictBuilder/*.c', '../../zstd/dictBuilder/*.h',
                       '../../zstd/legacy/*.c', '../../zstd/legacy/*.h',
                       '../../zstd/*.h'
  s.private_header_files = '../../zstd/**/*.h'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/../../zstd',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'OTHER_CFLAGS' => '$(inherited) -DZSTD_STATIC_LINKING_ONLY',
  }
  s.swift_version = '5.0'
end
