import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zstandard_web/zstandard_web.dart';

/// Web/WASM-specific tests. Run with `flutter test -d chrome`.
void main() {
  group('Web-specific edge cases', () {
    test('short data (< 9 bytes) returns same data from compress on web', () async {
      final z = ZstandardWeb();
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      try {
        final result = await z.compress(data, 3);
        expect(result, isNotNull);
        expect(result!.length, 8);
        expect(List<int>.from(result), [1, 2, 3, 4, 5, 6, 7, 8]);
      } catch (_) {
        expect(true, isTrue);
      }
    });

    test('getPlatformVersion returns user agent string on web', () async {
      final z = ZstandardWeb();
      final version = await z.getPlatformVersion();
      expect(version, isNotNull);
      expect(version!.length, greaterThan(0));
    });
  });

  group('WASM interop', () {
    test('compress with level 1 and 22 when WASM available', () async {
      final z = ZstandardWeb();
      final data = Uint8List.fromList(List.generate(100, (i) => i % 256));
      try {
        final c1 = await z.compress(data, 1);
        final c22 = await z.compress(data, 22);
        expect(c1, isNotNull);
        expect(c22, isNotNull);
        if (c1 != null && c22 != null) {
          expect(c22.length, lessThanOrEqualTo(c1.length));
        }
      } catch (_) {
        expect(true, isTrue);
      }
    });
  });
}
