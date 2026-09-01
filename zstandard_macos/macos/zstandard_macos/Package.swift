// swift-tools-version: 5.9
import PackageDescription

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
        .package(name: "FlutterMacOS", path: "../FlutterMacOS"),
        .package(
            url: "https://github.com/vypdev/zstandard.git",
            branch: "develop"
        ),
    ],
    targets: [
        .target(
            name: "zstandard_macos",
            dependencies: [
                .product(name: "FlutterMacOS", package: "FlutterMacOS"),
                .product(name: "zstandard-native", package: "zstandard"),
            ],
            path: "Sources/zstandard_macos",
        ),
    ]
)
