// swift-tools-version: 5.9
import Foundation
import PackageDescription

let nativePackageDependency: Package.Dependency = {
    if let localPath = ProcessInfo.processInfo.environment["ZSTANDARD_NATIVE_PACKAGE_PATH"] {
        return .package(name: "zstandard", path: localPath)
    }

    // Keep the C implementation in the repository-level SwiftPM package.
    // Pin this to a release tag before publishing the plugin package.
    return .package(
        url: "https://github.com/vypdev/zstandard.git",
        branch: "develop"
    )
}()

let package = Package(
    name: "zstandard_macos",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "zstandard-macos",
            targets: ["zstandard_macos"]
        ),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        nativePackageDependency,
    ],
    targets: [
        .target(
            name: "zstandard_macos",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "zstandard-native", package: "zstandard"),
            ],
            path: "Sources/zstandard_macos",
        ),
    ]
)
