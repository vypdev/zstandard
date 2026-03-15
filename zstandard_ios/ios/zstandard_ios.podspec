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

  # Zstd C sources live at repo root ../../zstd (single source of truth).
  # Pod root is this directory (ios/); paths are relative to it.
  s.source           = { :path => '.' }
  s.source_files =    '../../zstd/**/*.c', '../../zstd/**/*.h', 'Classes/*.swift'
  s.public_header_files = '../../zstd/zstd.h'

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  # HEADER_SEARCH_PATHS so zstd #includes resolve; no sync script needed.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_CFLAGS' => '-DZSTD_STATIC_LINKING_ONLY -DZSTD_DISABLE_ASM',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/../../zstd'
  }

  s.swift_version = '5.0'
end
