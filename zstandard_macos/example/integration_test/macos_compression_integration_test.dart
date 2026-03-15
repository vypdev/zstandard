import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:leak_tracker_testing/leak_tracker_testing.dart';
import 'package:zstandard_macos/zstandard_macos.dart';

/// macOS integration tests: run on macOS with app bundle (framework built). No skips.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ZstandardMacOS', () {
    late ZstandardMacOS zstandard;

    setUp(() {
      zstandard = ZstandardMacOS();
    });

    test('compress and decompress small data', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await zstandard.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await zstandard.decompress(compressed!);
      expect(decompressed, equals(data));
    });

    test('compress and decompress large data', () async {
      final data = Uint8List.fromList(List<int>.generate(100000, (i) => i % 256));
      final compressed = await zstandard.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await zstandard.decompress(compressed!);
      expect(decompressed, equals(data));
    });

    test('compress and decompress empty data', () async {
      final data = Uint8List(0);
      final compressed = await zstandard.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await zstandard.decompress(compressed!);
      expect(decompressed, equals(data));
    });

    test('compress with levels 1, 3, 10, 22', () async {
      final data = Uint8List.fromList(List.filled(1000, 42));
      for (final level in [1, 3, 10, 22]) {
        final compressed = await zstandard.compress(data, level);
        expect(compressed, isNotNull);
        final decompressed = await zstandard.decompress(compressed!);
        expect(decompressed, equals(data));
      }
    });

    test('decompress corrupted data returns null', () async {
      final corrupted = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final result = await zstandard.decompress(corrupted);
      expect(result, isNull);
    });

    test('decompress random bytes returns null', () async {
      final random = Uint8List.fromList(List.generate(64, (i) => (i * 31) % 256));
      final result = await zstandard.decompress(random);
      expect(result, isNull);
    });

    test('compress and decompress do not leak', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await zstandard.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await zstandard.decompress(compressed!);
      expect(decompressed, equals(data));
      if (LeakTracking.isStarted) {
        final leaks = await LeakTracking.collectLeaks();
        expect(leaks, isLeakFree);
      }
    });
  });
}
