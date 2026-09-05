import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Swift Package Manager consumes the shared native package', () {
    final manifest =
        File('macos/zstandard_macos/Package.swift').readAsStringSync();
    final rootManifest = File('../Package.swift');
    final duplicateSourceDirectory =
        Directory('macos/zstandard_macos/Sources/zstd');

    expect(manifest, contains('name: "zstandard_macos"'));
    expect(manifest, contains('name: "zstandard-macos"'));
    expect(manifest, contains('path: "Sources/zstandard_macos"'));
    expect(manifest, contains('ZSTANDARD_NATIVE_PACKAGE_PATH'));
    expect(manifest, contains('https://github.com/vypdev/zstandard.git'));
    // Development checkouts use develop; the release workflow rewrites this
    // to an exact immutable version before tagging a published archive.
    expect(
      manifest,
      anyOf(
        contains('branch: "develop"'),
        matches(RegExp(r'exact:\s*"\d+\.\d+\.\d+"')),
      ),
    );
    if (manifest.contains('exact:')) {
      expect(manifest, isNot(contains('branch: "develop"')));
    }
    expect(manifest, contains('product(name: "zstandard-native"'));
    expect(duplicateSourceDirectory.existsSync(), isFalse);
    if (rootManifest.existsSync()) {
      expect(rootManifest.readAsStringSync(),
          contains('path: "zstandard_native/src/zstd"'));
    }
  });
}
