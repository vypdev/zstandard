import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Swift Package Manager consumes the shared native package', () {
    final manifest =
        File('macos/zstandard_macos/Package.swift').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)$',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1)!;
    final rootManifest = File('../Package.swift');
    final duplicateSourceDirectory = Directory(
      'macos/zstandard_macos/Sources/zstd',
    );

    expect(manifest, contains('name: "zstandard_macos"'));
    expect(manifest, contains('name: "zstandard-macos"'));
    expect(manifest, contains('path: "Sources/zstandard_macos"'));
    expect(manifest, contains('ZSTANDARD_NATIVE_PACKAGE_PATH'));
    expect(manifest, contains('https://github.com/vypdev/zstandard.git'));
    expect(manifest, contains('exact: "$version"'));
    expect(manifest, isNot(contains('branch:')));
    expect(manifest, contains('product(name: "zstandard-native"'));
    expect(duplicateSourceDirectory.existsSync(), isFalse);
    if (rootManifest.existsSync()) {
      final rootContents = rootManifest.readAsStringSync();
      expect(rootContents, contains('path: "zstandard_native/src/zstd"'));
      for (final symbol in [
        '_ZSTD_compress',
        '_ZSTD_decompress',
        '_ZSTD_isError',
        '_ZSTD_createDStream',
        '_ZSTD_initDStream',
        '_ZSTD_decompressStream',
        '_ZSTD_freeDStream',
        '_ZSTD_DStreamOutSize',
      ]) {
        expect(rootContents, contains(symbol));
      }
    }
  });
}
