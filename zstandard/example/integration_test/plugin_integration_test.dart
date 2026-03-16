// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zstandard/zstandard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Zstandard plugin;

  setUp(() {
    plugin = Zstandard();
  });

  testWidgets('getPlatformVersion test', (WidgetTester tester) async {
    final String? version = await plugin.getPlatformVersion();
    expect(version?.isNotEmpty, true);
  });

  group('Compression roundtrip', () {
    test('roundtrip small data level 3', () async {
      final data = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final compressed = await plugin.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await plugin.decompress(compressed!);
      expect(decompressed, isNotNull);
      expect(decompressed, data);
    });

    test('roundtrip with level 1', () async {
      final data = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final compressed = await plugin.compress(data, 1);
      expect(compressed, isNotNull);
      final decompressed = await plugin.decompress(compressed!);
      expect(decompressed, data);
    });

    test('roundtrip with level 22', () async {
      final data = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final compressed = await plugin.compress(data, 22);
      expect(compressed, isNotNull);
      final decompressed = await plugin.decompress(compressed!);
      expect(decompressed, data);
    });

    test('roundtrip empty data', () async {
      final data = Uint8List(0);
      final compressed = await plugin.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await plugin.decompress(compressed!);
      expect(decompressed, isNotNull);
      expect(decompressed!.length, 0);
    });

    test('roundtrip medium data (10KB)', () async {
      final data = Uint8List.fromList(List.generate(10000, (i) => i % 256));
      final compressed = await plugin.compress(data, 3);
      expect(compressed, isNotNull);
      expect(compressed!.length, lessThanOrEqualTo(data.length + 256));
      final decompressed = await plugin.decompress(compressed);
      expect(decompressed, data);
    });

    test('roundtrip repeated pattern', () async {
      final data = Uint8List.fromList(List.filled(1000, 0x42));
      final compressed = await plugin.compress(data, 10);
      expect(compressed, isNotNull);
      final decompressed = await plugin.decompress(compressed!);
      expect(decompressed, data);
    });
  });

  group('Decompress invalid input', () {
    test('corrupted data returns null', () async {
      final corrupted = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final result = await plugin.decompress(corrupted);
      expect(result, isNull);
    });

    test('random bytes return null', () async {
      final random = Uint8List.fromList(List.generate(50, (i) => (i * 7) % 256));
      final result = await plugin.decompress(random);
      expect(result, isNull);
    });
  });

  group('Extension methods', () {
    test('compress extension roundtrip', () async {
      final data = Uint8List.fromList(List.generate(200, (i) => i % 256));
      final compressed = await data.compress(compressionLevel: 3);
      expect(compressed, isNotNull);
      final decompressed = await compressed!.decompress();
      expect(decompressed, data);
    });

    test('null extension returns null', () async {
      Uint8List? nullData;
      final compressed = await nullData.compress();
      expect(compressed, isNull);
    });
  });
}
