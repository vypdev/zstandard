import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zstandard_android/zstandard_android.dart';

void main() {
  final bool skipPlatform = !Platform.isAndroid;

  group('ZstandardAndroid', () {
    late ZstandardAndroid zstandard;

    setUp(() {
      zstandard = ZstandardAndroid();
    });

    test('compress and decompress small data', () async {
      if (skipPlatform) return;
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await zstandard.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await zstandard.decompress(compressed!);
      expect(decompressed, equals(data));
    }, skip: skipPlatform ? 'Only runs on Android' : false);

    test('compress and decompress large data', () async {
      if (skipPlatform) return;
      final data = Uint8List.fromList(List<int>.generate(100000, (i) => i % 256));
      final compressed = await zstandard.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await zstandard.decompress(compressed!);
      expect(decompressed, equals(data));
    }, skip: skipPlatform ? 'Only runs on Android' : false);

    test('compress and decompress empty data', () async {
      if (skipPlatform) return;
      final data = Uint8List(0);
      final compressed = await zstandard.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await zstandard.decompress(compressed!);
      expect(decompressed, equals(data));
    }, skip: skipPlatform ? 'Only runs on Android' : false);

    test('compress with levels 1, 3, 10, 22', () async {
      if (skipPlatform) return;
      final data = Uint8List.fromList(List.filled(1000, 42));
      for (final level in [1, 3, 10, 22]) {
        final compressed = await zstandard.compress(data, level);
        expect(compressed, isNotNull);
        final decompressed = await zstandard.decompress(compressed!);
        expect(decompressed, equals(data));
      }
    }, skip: skipPlatform ? 'Only runs on Android' : false);
  });
}
