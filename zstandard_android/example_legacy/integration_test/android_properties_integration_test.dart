import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiri_check/kiri_check.dart';
import 'package:zstandard_android/zstandard_android.dart';

/// Property-based integration tests for Android. Run on device/emulator. No skips.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Property-based tests', () {
    property('roundtrip: decompress(compress(x)) == x', () {
      forAll(binary(minLength: 1, maxLength: 1000), (List<int> data) async {
        final input = Uint8List.fromList(data);
        expect(input, isNotEmpty);
        final z = ZstandardAndroid();
        final compressed = await z.compress(input, 3);
        expect(compressed, isNotNull);
        expect(compressed!.isNotEmpty, isTrue);
        final decompressed = await z.decompress(compressed);
        expect(decompressed, isNotNull);
        expect(List<int>.from(decompressed!), data);
      }, maxExamples: 100);
    });
  });
}
