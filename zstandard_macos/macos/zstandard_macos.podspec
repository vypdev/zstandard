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

  # Classes/ contains the plugin (Swift + forwarder .c) and Classes/zstd/ is a
  # copy of ../src so the zstd C library is compiled into the framework.
  # The framework must export ZSTD_* symbols (e.g. ZSTD_compressBound) for FFI.
  # Keep zstd headers private so the module umbrella does not break relative includes.
  s.source           = { :path => '.' }
  # Exclude deprecated/ (zbuff) to avoid module/macro issues; include legacy for decompress.
  s.source_files     = 'Classes/zstandard_macos.c', 'Classes/**/*.swift',
                       'Classes/zstd/common/*.c', 'Classes/zstd/common/*.h',
                       'Classes/zstd/compress/*.c', 'Classes/zstd/compress/*.h',
                       'Classes/zstd/decompress/*.c', 'Classes/zstd/decompress/*.h',
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
  s.swift_version = '5.0'
end
