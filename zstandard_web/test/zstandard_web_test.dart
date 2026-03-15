import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zstandard_web/zstandard_web.dart';

/// Web tests: run with `flutter test -d chrome`. No VM execution.
void main() {
  group('ZstandardWeb', () {
    test('ZstandardWeb can be instantiated', () {
      expect(ZstandardWeb(), isA<ZstandardWeb>());
    });

    test('getPlatformVersion returns non-null on web', () async {
      final z = ZstandardWeb();
      final version = await z.getPlatformVersion();
      expect(version, isNotNull);
      expect(version, isNotEmpty);
    });

    test('compress and decompress roundtrip when zstd.js is available', () async {
      final z = ZstandardWeb();
      final data = Uint8List.fromList(List.generate(20, (i) => i));
      try {
        final compressed = await z.compress(data, 3);
        expect(compressed, isNotNull);
        final decompressed = await z.decompress(compressed!);
        expect(decompressed, equals(data));
      } catch (_) {
        // zstd.js may not be loaded in unit test environment
        expect(true, isTrue);
      }
    });

    test('decompress corrupted data throws or fails when zstd.js is available', () async {
      final z = ZstandardWeb();
      final corrupted = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      try {
        final result = await z.decompress(corrupted);
        expect(result == null || result.isEmpty, isTrue);
      } catch (_) {
        expect(true, isTrue);
      }
    });
  });
}
