// swift-tools-version: 5.9
import PackageDescription

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
        // The repository root package exposes the canonical C implementation
        // from zstandard_native/src/zstd without copying it into this plugin.
        // Use the development branch until the first release containing this
        // SwiftPM facade is tagged; release builds should pin that tag.
        .package(
            url: "https://github.com/vypdev/zstandard.git",
            branch: "develop"
        ),
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
