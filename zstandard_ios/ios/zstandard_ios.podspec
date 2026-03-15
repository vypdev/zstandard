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

  # Zstd C sources: synced from repo root zstd/ into Classes/zstd/ by
  # scripts/sync_zstd_ios_macos.sh (run in a before_compile script phase when present).
  s.source           = { :path => '.' }
  s.source_files =    'Classes/zstd/**/*.c', 'Classes/zstd/**/*.h', 'Classes/*.swift'
  s.public_header_files = 'Classes/zstd/zstd.h'

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_CFLAGS' => '-DZSTD_STATIC_LINKING_ONLY -DZSTD_DISABLE_ASM'
  }

  # Sync zstd before compile when script exists (local dev); no need for Podfile pre_install.
  # After compile, remove synced copy so Classes/zstd is not left on disk.
  s.script_phases = [
    {
      :name => 'Sync zstd',
      :script => <<~SCRIPT,
        SCRIPT="${PODS_TARGET_SRCROOT}/../../scripts/sync_zstd_ios_macos.sh"
        if [ -x "$SCRIPT" ]; then
          "$SCRIPT" ios
        fi
      SCRIPT
      :execution_position => :before_compile
    },
    { :name => 'Remove synced zstd', :script => 'rm -rf "${PODS_TARGET_SRCROOT}/Classes/zstd"', :execution_position => :after_compile }
  ]

  s.swift_version = '5.0'
end
