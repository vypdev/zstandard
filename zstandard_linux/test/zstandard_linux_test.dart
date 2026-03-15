import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:leak_tracker_testing/leak_tracker_testing.dart';
import 'package:zstandard_linux/zstandard_linux.dart';

void main() {
  final bool skipPlatform = !Platform.isLinux;

  group('ZstandardLinux', () {
    late ZstandardLinux zstandard;

    setUp(() {
      zstandard = ZstandardLinux();
    });

    test('compress and decompress small data', () async {
      if (skipPlatform) return;
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await zstandard.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await zstandard.decompress(compressed!);
      expect(decompressed, equals(data));
    }, skip: skipPlatform ? 'Only runs on Linux' : false);

    test('compress and decompress large data', () async {
      if (skipPlatform) return;
      final data = Uint8List.fromList(List<int>.generate(100000, (i) => i % 256));
      final compressed = await zstandard.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await zstandard.decompress(compressed!);
      expect(decompressed, equals(data));
    }, skip: skipPlatform ? 'Only runs on Linux' : false);

    test('compress and decompress empty data', () async {
      if (skipPlatform) return;
      final data = Uint8List(0);
      final compressed = await zstandard.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await zstandard.decompress(compressed!);
      expect(decompressed, equals(data));
    }, skip: skipPlatform ? 'Only runs on Linux' : false);

    test('compress with levels 1, 3, 10, 22', () async {
      if (skipPlatform) return;
      final data = Uint8List.fromList(List.filled(1000, 42));
      for (final level in [1, 3, 10, 22]) {
        final compressed = await zstandard.compress(data, level);
        expect(compressed, isNotNull);
        final decompressed = await zstandard.decompress(compressed!);
        expect(decompressed, equals(data));
      }
    }, skip: skipPlatform ? 'Only runs on Linux' : false);

    test('decompress corrupted data returns null', () async {
      if (skipPlatform) return;
      final corrupted = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final result = await zstandard.decompress(corrupted);
      expect(result, isNull);
    }, skip: skipPlatform ? 'Only runs on Linux' : false);

    test('decompress random bytes returns null', () async {
      if (skipPlatform) return;
      final random = Uint8List.fromList(List.generate(64, (i) => (i * 31) % 256));
      final result = await zstandard.decompress(random);
      expect(result, isNull);
    }, skip: skipPlatform ? 'Only runs on Linux' : false);

    test('compress and decompress do not leak', () async {
      if (skipPlatform) return;
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await zstandard.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await zstandard.decompress(compressed!);
      expect(decompressed, equals(data));
      if (LeakTracking.isStarted) {
        final leaks = await LeakTracking.collectLeaks();
        expect(leaks, isLeakFree);
      }
    }, skip: skipPlatform ? 'Only runs on Linux' : false);
  });
}
