#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zstandard_ios.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'zstandard_ios'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files =    'Classes/zstd/**/*.c', 'Classes/zstd/**/*.h', 'Classes/*.swift'
  s.public_header_files = 'Classes/zstd/zstd.h'

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  # Run ./scripts/sync_zstd_ios_macos.sh after updating zstd; it removes module.modulemap on iOS
  # so legacy/*.c use their local ZSTD_parameters (with .windowLog), not the one from zstd.h.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_CFLAGS' => '-DZSTD_STATIC_LINKING_ONLY -DZSTD_DISABLE_ASM'
  }

  s.swift_version = '5.0'
end
