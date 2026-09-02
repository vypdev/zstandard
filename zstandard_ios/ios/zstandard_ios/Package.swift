// swift-tools-version: 5.9
import Foundation
import PackageDescription

let nativePackageDependency: Package.Dependency = {
    if let localPath = ProcessInfo.processInfo.environment["ZSTANDARD_NATIVE_PACKAGE_PATH"] {
        return .package(name: "zstandard", path: localPath)
    }

    // The repository root package exposes the canonical C implementation
    // from zstandard_native/src/zstd without copying it into this plugin.
    // Use the development branch until the first release containing this
    // SwiftPM facade is tagged; release builds should pin that tag.
    return .package(
        url: "https://github.com/vypdev/zstandard.git",
        branch: "develop"
    )
}()

let package = Package(
    name: "zstandard_ios",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "zstandard-ios",
            targets: ["zstandard_ios"]
        ),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        nativePackageDependency,
    ],
    targets: [
        .target(
            name: "zstandard_ios",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "zstandard-native", package: "zstandard"),
            ],
            path: "Sources/zstandard_ios",
        ),
    ]
)
