// swift-tools-version: 5.9
import PackageDescription

// SwiftPM facade for the canonical native implementation kept in
// zstandard_native/src/zstd. Platform packages depend on this product instead
// of carrying another copy of the C sources.
let package = Package(
    name: "zstandard_native",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "zstandard-native",
            targets: ["zstandard_native"]
        ),
    ],
    targets: [
        .target(
            name: "zstandard_native",
            path: "zstandard_native/src/zstd",
            exclude: [
                "deprecated",
                "dictBuilder",
                "dll",
                "legacy",
                "decompress/huf_decompress_amd64.S",
                "module.modulemap",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("include"),
                .define("ZSTD_STATIC_LINKING_ONLY"),
                .define("ZSTD_DISABLE_ASM"),
            ]
        ),
    ]
)
