# Apple Dependency Strategy

## Current policy

iOS and macOS use CocoaPods as the only supported native dependency manager in
this repository.

The canonical zstd C source is kept in
`zstandard_native/src/zstd/`. It is not duplicated in either Apple plugin. The
CocoaPods podspecs run the corresponding sync script at install time and in a
build script phase, refreshing the ignored generated copies at
`zstandard_ios/ios/Classes/zstd/` and `zstandard_macos/macos/Classes/zstd/`.
Those generated directories must not be edited or committed.

The Swift plugin sources remain in each plugin's `ios/Classes/` or
`macos/Classes/` directory, as required by the CocoaPods podspec.

## Why Swift Package Manager is deferred

Swift Package Manager was investigated as a way for Apple platforms to consume
the canonical native source without generated CocoaPods copies. The experiment
is intentionally not part of the supported implementation yet:

1. The self-hosted Apple CI runner is an Intel Mac running macOS Ventura and an
   older Xcode release.
2. The Flutter toolchain currently selected by the repository CI cannot start
   on that runner's macOS version, so a Swift Package Manager build cannot be
   validated there.
3. Shipping an untestable dependency path would make the result less reliable
   than the CocoaPods path already covered by the existing plugin integration
   tests.

For this reason, the repository contains no Swift Package Manager manifests,
SwiftPM-only header bridges, or SwiftPM-specific tests. The iOS and macOS
workflows exercise CocoaPods and retain their push checks for `develop`.

## Reconsideration checklist

Swift Package Manager may be reconsidered when CI has a supported Apple
toolchain and can validate, from a clean checkout:

- an iOS simulator build and integration test;
- a macOS build and integration test;
- both debug and release configurations; and
- the absence of a second checked-in zstd source tree.

Until then, update `zstandard_native/src/zstd/` and use the CocoaPods sync
scripts when changing the native library. The generated Apple copies are
implementation details of the CocoaPods build and are intentionally retained
after compilation so that Xcode cannot delete sources while compiling them.
