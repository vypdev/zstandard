import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Swift Package Manager consumes the shared native package', () {
    final manifest = File('ios/zstandard_ios/Package.swift').readAsStringSync();
    final rootManifest = File('../Package.swift');
    final duplicateSourceDirectory =
        Directory('ios/zstandard_ios/Sources/zstd');

    expect(manifest, contains('name: "zstandard_ios"'));
    expect(manifest, contains('name: "zstandard-ios"'));
    expect(manifest, contains('path: "Sources/zstandard_ios"'));
    expect(manifest, contains('https://github.com/vypdev/zstandard.git'));
    expect(manifest, contains('branch: "develop"'));
    expect(manifest, contains('product(name: "zstandard-native"'));
    expect(duplicateSourceDirectory.existsSync(), isFalse);
    if (rootManifest.existsSync()) {
      expect(rootManifest.readAsStringSync(),
          contains('path: "zstandard_native/src/zstd"'));
    }
  });
}
