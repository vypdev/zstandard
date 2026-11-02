#!/usr/bin/env python3
"""Build a version-resolved SwiftPM consumer and check Release FFI symbols.

The dependency is an isolated, locally tagged copy of the candidate source.
A path or revision dependency would bypass SwiftPM's unsafe-flags check.
"""
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

PROBE = r'''#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <zstd.h>
#include <zstandard_ffi.h>

#define REQUIRE(condition) do { \
    if (!(condition)) { \
        fprintf(stderr, "Failed: %s\n", #condition); \
        return 1; \
    } \
} while (0)

#define LOAD(name) \
    __typeof__(&name) name##Fn = (__typeof__(&name))dlsym(RTLD_DEFAULT, #name); \
    REQUIRE(name##Fn != NULL)

int main(void) {
    ZstandardNativeRetainSymbols();
    LOAD(ZSTD_compress);
    LOAD(ZSTD_decompress);
    LOAD(ZSTD_compressBound);
    LOAD(ZSTD_isError);
    LOAD(ZSTD_getFrameContentSize);
    LOAD(ZSTD_createDStream);
    LOAD(ZSTD_initDStream);
    LOAD(ZSTD_decompressStream);
    LOAD(ZSTD_freeDStream);
    LOAD(ZSTD_DStreamOutSize);

    const char input[] = "Version-resolved SwiftPM FFI roundtrip";
    char compressed[256];
    char output[256];
    REQUIRE(ZSTD_compressBoundFn(sizeof(input)) <= sizeof(compressed));
    size_t size = ZSTD_compressFn(compressed, sizeof(compressed), input, sizeof(input), 3);
    REQUIRE(!ZSTD_isErrorFn(size));
    REQUIRE(ZSTD_getFrameContentSizeFn(compressed, size) == sizeof(input));
    REQUIRE(ZSTD_decompressFn(output, sizeof(output), compressed, size) == sizeof(input));
    REQUIRE(memcmp(input, output, sizeof(input)) == 0);

    ZSTD_DStream *stream = ZSTD_createDStreamFn();
    REQUIRE(stream != NULL);
    REQUIRE(!ZSTD_isErrorFn(ZSTD_initDStreamFn(stream)));
    REQUIRE(ZSTD_DStreamOutSizeFn() > 0);
    ZSTD_inBuffer source = { compressed, size, 0 };
    ZSTD_outBuffer destination = { output, sizeof(output), 0 };
    REQUIRE(ZSTD_decompressStreamFn(stream, &destination, &source) == 0);
    REQUIRE(source.pos == size && destination.pos == sizeof(input));
    REQUIRE(memcmp(input, output, sizeof(input)) == 0);
    REQUIRE(!ZSTD_isErrorFn(ZSTD_freeDStreamFn(stream)));
    puts("All 10 FFI symbols survive Release dead stripping; one-shot and streaming roundtrips pass.");
    return 0;
}
'''


def run(*command, cwd):
    subprocess.run(command, cwd=cwd, check=True, timeout=300)


def main():
    if platform.system() != 'Darwin':
        raise SystemExit('This Apple linker regression test requires macOS and Swift.')
    with tempfile.TemporaryDirectory(prefix='zstandard-swiftpm-') as folder:
        root = Path(folder)
        dependency = root / 'zstandard'
        dependency.mkdir()
        shutil.copyfile(ROOT / 'Package.swift', dependency / 'Package.swift')
        shutil.copytree(ROOT / 'zstandard_native/src', dependency / 'zstandard_native/src')
        run('git', 'init', '-q', cwd=dependency)
        run('git', 'add', '.', cwd=dependency)
        run('git', '-c', 'user.name=SwiftPM regression', '-c',
            'user.email=swiftpm-test@example.invalid', 'commit', '-qm', 'Candidate fixture', cwd=dependency)
        run('git', 'tag', '1.0.0', cwd=dependency)

        consumer = root / 'consumer'
        (consumer / 'Sources/Probe').mkdir(parents=True)
        (consumer / 'Sources/Probe/main.c').write_text(PROBE)
        (consumer / 'Package.swift').write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Probe",
    platforms: [.macOS(.v10_15)],
    dependencies: [.package(url: "''' + dependency.as_uri() + '''", exact: "1.0.0")],
    targets: [.executableTarget(name: "Probe", dependencies: [
        .product(name: "zstandard-native", package: "zstandard")
    ])]
)
''')
        build = root / 'build'
        run('swift', 'build', '--configuration', 'release', '--scratch-path', str(build),
            '--cache-path', str(root / 'cache'), '-Xlinker', '-dead_strip', cwd=consumer)
        run(str(build / 'release/Probe'), cwd=consumer)


if __name__ == '__main__':
    main()
