// swift-tools-version: 5.9
import PackageDescription

// SwiftPM facade for the canonical native implementation kept in
// zstandard_native/src/zstd. The Apple platform packages depend on this
// product instead of carrying another copy of the C sources.
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
            ],
            // Flutter's SwiftPM integration links this target statically into
            // the application. Keep the FFI entry points in the final image
            // even when release dead-code stripping is enabled.
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-u", "-Xlinker", "_ZSTD_compress",
                    "-Xlinker", "-u", "-Xlinker", "_ZSTD_decompress",
                    "-Xlinker", "-u", "-Xlinker", "_ZSTD_compressBound",
                    "-Xlinker", "-u", "-Xlinker", "_ZSTD_getFrameContentSize",
                ])
            ]
        ),
    ]
)
