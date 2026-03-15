import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiri_check/kiri_check.dart';
import 'package:zstandard_web/zstandard_web.dart';

/// Property-based web tests: run with `flutter test -d chrome`.
void main() {
  group('Property-based tests', () {
    property(
      'roundtrip: decompress(compress(x)) == x',
      () {
        forAll(
          binary(minLength: 9, maxLength: 1000),
          (List<int> data) async {
            final input = Uint8List.fromList(data);
            final z = ZstandardWeb();
            final compressed = await z.compress(input, 3);
            if (compressed == null) return;
            final decompressed = await z.decompress(compressed);
            expect(decompressed, isNotNull);
            expect(List<int>.from(decompressed!), data);
          },
          maxExamples: 50,
        );
      },
    );
  });
}
