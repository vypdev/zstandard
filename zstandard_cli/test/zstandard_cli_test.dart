import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zstandard_cli/zstandard_cli.dart';

void main() {
  final bool skipPlatform = !Platform.isMacOS && !Platform.isWindows && !Platform.isLinux;

  group('Zstandard CLI tests', () {
    test('getPlatformVersion returns non-null string on supported platform', () async {
      if (skipPlatform) return;
      final cli = ZstandardCLI();
      final version = await cli.getPlatformVersion();
      expect(version, isNotNull);
      expect(version, isNotEmpty);
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('ZstandardCLI can be instantiated on supported platform', () {
      if (skipPlatform) return;
      expect(ZstandardCLI(), isA<ZstandardCLI>());
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);
    test('Compress and decompress small Uint8List', () async {
      final Uint8List sample = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress large Uint8List', () async {
      final Uint8List sample =
          Uint8List.fromList(List<int>.generate(100000, (i) => i % 256));
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress empty Uint8List', () async {
      final Uint8List sample = Uint8List(0);
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(sample, equals(compressed));
      expect(sample.length, equals(compressed?.length));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress Uint8List with repeated values', () async {
      final Uint8List sample = Uint8List.fromList(List.filled(1000, 42));
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress with maximum compression level', () async {
      final Uint8List sample =
          Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final compressed = await sample.compress(compressionLevel: 22);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress with minimal compression level', () async {
      final Uint8List sample =
          Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final compressed = await sample.compress(compressionLevel: 1);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress with level 22 produces valid decompressible output', () async {
      final Uint8List sample = Uint8List.fromList(List.filled(500, 7));
      final compressed = await sample.compress(compressionLevel: 22);
      expect(compressed, isNotNull);
      final decompressed = await compressed!.decompress();
      expect(decompressed, equals(sample));
    });

    test('Null extension receiver returns null from compress', () async {
      const Uint8List? nullData = null;
      final result = await nullData.compress();
      expect(result, isNull);
    });

    test('Null extension receiver returns null from decompress', () async {
      const Uint8List? nullData = null;
      final result = await nullData.decompress();
      expect(result, isNull);
    });

    test('decompress corrupted data returns null', () async {
      if (skipPlatform) return;
      final corrupted = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final cli = ZstandardCLI();
      final result = await cli.decompress(corrupted);
      expect(result, isNull);
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('decompress random bytes returns null', () async {
      if (skipPlatform) return;
      final random = Uint8List.fromList(List.generate(64, (i) => (i * 31) % 256));
      final cli = ZstandardCLI();
      final result = await cli.decompress(random);
      expect(result, isNull);
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);
  });
}
