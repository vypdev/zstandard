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
  # scripts/sync_zstd_ios_macos.sh. Must exist at pod install time so source_files glob finds them.
  s.source           = { :path => '.' }
  s.source_files =    'Classes/zstd/**/*.c', 'Classes/zstd/**/*.h', 'Classes/*.swift'
  s.public_header_files = 'Classes/zstd/zstd.h'

  # Run at pod install so Classes/zstd exists when CocoaPods globs source_files (path pods only).
  s.prepare_command = <<~CMD
    bash -c '[ -x "../../scripts/sync_zstd_ios_macos.sh" ] && "../../scripts/sync_zstd_ios_macos.sh" ios'
  CMD

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_CFLAGS' => '-DZSTD_STATIC_LINKING_ONLY -DZSTD_DISABLE_ASM'
  }

  # before_compile: sync again so build sees latest zstd. Remove uses :any so it runs last and
  # does not delete the source before another target that might need it has run.
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
    { :name => 'Remove synced zstd', :script => 'rm -rf "${PODS_TARGET_SRCROOT}/Classes/zstd"', :execution_position => :any }
  ]

  s.swift_version = '5.0'
end
