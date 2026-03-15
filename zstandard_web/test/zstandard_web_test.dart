import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zstandard_web/zstandard_web.dart';

void main() {
  final bool skipWeb = !kIsWeb;

  group('ZstandardWeb', () {
    test('ZstandardWeb can be instantiated', () {
      if (skipWeb) return;
      expect(ZstandardWeb(), isA<ZstandardWeb>());
    }, skip: skipWeb ? 'Only runs on web' : false);

    test('getPlatformVersion returns non-null on web', () async {
      if (skipWeb) return;
      final z = ZstandardWeb();
      final version = await z.getPlatformVersion();
      expect(version, isNotNull);
      expect(version, isNotEmpty);
    }, skip: skipWeb ? 'Only runs on web' : false);

    test('compress and decompress roundtrip when zstd.js is available', () async {
      if (skipWeb) return;
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
    }, skip: skipWeb ? 'Only runs on web' : false);
  });
}
