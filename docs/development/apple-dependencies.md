# Apple Dependency Strategy

## Supported dependency managers

iOS and macOS support both Swift Package Manager and CocoaPods.

Swift Package Manager is the primary path for current Flutter projects. The
Apple plugin packages expose a SwiftPM target that links the canonical C
implementation from the repository-level `Package.swift`. CocoaPods remains
available for applications and Flutter versions that still use podspecs.

The canonical zstd C source is kept only in
`zstandard_native/src/zstd/`. The repository-level SwiftPM facade exposes that
directory as the `zstandard-native` product. CocoaPods cannot consume a Dart
package as a native target, so the podspecs refresh ignored generated copies
under `ios/Classes/zstd/` and `macos/Classes/zstd/` at install/build time.
Those copies are a CocoaPods compatibility mechanism, not a second source of
truth, and must not be edited or committed.

The Swift plugin sources live under the SwiftPM-standard paths:

- `zstandard_ios/ios/zstandard_ios/Sources/zstandard_ios/`
- `zstandard_macos/macos/zstandard_macos/Sources/zstandard_macos/`

The CocoaPods podspecs point to those same Swift files, so the two dependency
managers build the same plugin implementation.

## Swift Package Manager dependency

The iOS and macOS manifests depend on the repository-level SwiftPM facade:

```swift
.package(
    url: "https://github.com/vypdev/zstandard.git",
    exact: "1.5.0"
)
```

The dependency is always immutable and matches the plugin package version.
Release preparation updates both manifests to the requested exact version;
mutable branches are never used in a published manifest.

The SwiftPM target deliberately excludes unsupported or unnecessary upstream
directories and disables assembly for the Apple build. It also preserves the
FFI entry points when release dead-code stripping is enabled. The public
headers in `zstandard_native/src/zstd/include/` are thin forwarding headers;
the actual headers and all C implementation files remain in the canonical
directory.

SwiftPM links the C target statically into the application, so the Apple Dart
bindings use `DynamicLibrary.process()` as a fallback. CocoaPods continues to
load the embedded plugin framework. This distinction is covered by the
native integration tests, not only by manifest parsing.

## Verification policy

Every Apple change must be tested through both dependency managers on the
ARM64 self-hosted macOS runner:

- unsigned iOS device Release builds plus simulator Debug builds and
  integration tests with Swift Package Manager;
- unsigned iOS device Release builds plus simulator Debug builds and
  integration tests with CocoaPods;
- macOS application builds and integration tests with Swift Package Manager; and
- macOS application builds and integration tests with CocoaPods.

The iOS workflow boots a simulator with `xcrun simctl` and never opens the
Simulator application. The macOS workflow builds the application explicitly,
then `flutter test -d macos` launches it and runs the integration suite in the
runner's existing graphical session. macOS applications still require a
WindowServer session, so the macOS runner must remain logged in even though no
manual interaction is needed.

The matrix also exercises the platform packages with the current Dart
`zstandard_native` package staged outside the repository. In the workspace
rows, SwiftPM receives `ZSTANDARD_NATIVE_PACKAGE_PATH` for the checkout root.
In the package-config rows, Dart, CocoaPods, and SwiftPM all receive the exact
external path to the same candidate source. This catches accidental reliance
on the monorepo's sibling-directory layout without compiling against an older
version from the runner's Pub cache.

The workflows use Flutter 3.47.2, which is new enough for Flutter's default
SwiftPM integration. CocoaPods jobs explicitly disable SwiftPM so that both
paths are tested independently. Jobs that change this persistent Flutter
preference share a non-cancelling concurrency group across iOS, macOS, and
release validation, and cleanup restores CocoaPods mode.

Flutter generates its ephemeral `FlutterFramework` dependency beside the
example application's generated plugin package. The platform plugin itself
remains in the checkout in both source-layout rows, so no CI-only manifest or
framework copy is required.

## Migration policy

Do not remove CocoaPods support yet. Flutter recommends that plugin authors
support both systems during the transition. CocoaPods is in maintenance mode,
but existing pod-based builds remain a supported compatibility path. When the
minimum Flutter version is raised to a SwiftPM-only release and a breaking
package release is planned, reassess whether the podspecs and generated
compatibility copies can be removed.

When updating zstd:

1. Update `zstandard_native/src/zstd/`.
2. Validate the repository-level SwiftPM target.
3. Run both CocoaPods sync scripts if the generated compatibility trees are
   needed locally.
4. Run the Apple CI matrix in both dependency-manager modes.

Never edit generated `Classes/zstd/` files directly.
