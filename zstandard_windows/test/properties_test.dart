import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiri_check/kiri_check.dart';
import 'package:zstandard_windows/zstandard_windows.dart';

void main() {
  final bool skipPlatform = !Platform.isWindows;

  group('Property-based tests', () {
    property(
      'roundtrip: decompress(compress(x)) == x',
      () {
        forAll(
          binary(minLength: 0, maxLength: 1000),
          (List<int> data) async {
            if (skipPlatform) return;
            final input = Uint8List.fromList(data);
            final z = ZstandardWindows();
            final compressed = await z.compress(input, 3);
            if (compressed == null) return;
            final decompressed = await z.decompress(compressed);
            expect(decompressed, isNotNull);
            expect(List<int>.from(decompressed!), data);
          },
          maxExamples: 100,
        );
      },
      skip: skipPlatform ? 'Only runs on Windows' : null,
    );
  });
}
