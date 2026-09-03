import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zstandard_android/zstandard_android.dart';

/// Deterministic round-trip integration tests for Android. Run on
/// device/emulator. No skips.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('roundtrip 100 deterministic non-empty byte arrays', () async {
    final z = ZstandardAndroid();

    for (var caseIndex = 0; caseIndex < 100; caseIndex++) {
      final length = 1 + ((caseIndex * 37) % 1000);
      final input = Uint8List.fromList(
        List<int>.generate(
          length,
          (index) => (index * 17 + caseIndex * 31) % 256,
        ),
      );
      expect(input, isNotEmpty);

      final compressed = await z.compress(input, 3);
      expect(compressed, isNotNull);
      expect(compressed!.isNotEmpty, isTrue);

      final decompressed = await z.decompress(compressed);
      expect(decompressed, isNotNull);
      expect(List<int>.from(decompressed!), equals(List<int>.from(input)));
    }
  });
}
