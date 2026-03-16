import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:zstandard/zstandard.dart';
import 'package:zstandard_platform_interface/zstandard_platform_interface.dart';

/// Mock that echoes data for roundtrip-style tests.
class EchoMockPlatform with MockPlatformInterfaceMixin implements ZstandardPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('EchoMock 1.0');

  @override
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) async {
    return Uint8List.fromList(List<int>.from(data));
  }

  @override
  Future<Uint8List?> decompress(Uint8List data) async {
    return Uint8List.fromList(List<int>.from(data));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Compression levels boundary tests', () {
    ZstandardPlatform? saved;

    setUp(() {
      Zstandard().instance;
      saved = ZstandardPlatform.instance;
      ZstandardPlatform.instance = EchoMockPlatform();
    });

    tearDown(() {
      ZstandardPlatform.instance = saved!;
    });

    test('level 1 forwards correctly', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final result = await Zstandard().compress(data, 1);
      expect(result, isNotNull);
      expect(result!.length, 3);
    });

    test('level 3 forwards correctly', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final result = await Zstandard().compress(data, 3);
      expect(result, isNotNull);
    });

    test('level 22 forwards correctly', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final result = await Zstandard().compress(data, 22);
      expect(result, isNotNull);
    });
  });

  group('Data size edge cases', () {
    ZstandardPlatform? saved;

    setUp(() {
      Zstandard().instance;
      saved = ZstandardPlatform.instance;
      ZstandardPlatform.instance = EchoMockPlatform();
    });

    tearDown(() {
      ZstandardPlatform.instance = saved!;
    });

    test('empty data roundtrip', () async {
      final data = Uint8List(0);
      final compressed = await Zstandard().compress(data, 3);
      expect(compressed, isNotNull);
      expect(compressed!.length, 0);
      final decompressed = await Zstandard().decompress(compressed);
      expect(decompressed, isNotNull);
      expect(decompressed!.length, 0);
    });

    test('1 byte data roundtrip', () async {
      final data = Uint8List.fromList([42]);
      final compressed = await Zstandard().compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await Zstandard().decompress(compressed!);
      expect(decompressed, equals(data));
    });

    test('small data roundtrip', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final compressed = await Zstandard().compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await Zstandard().decompress(compressed!);
      expect(decompressed, equals(data));
    });

    test('medium data (10KB) roundtrip', () async {
      final data = Uint8List.fromList(List.generate(10 * 1024, (i) => i % 256));
      final compressed = await Zstandard().compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed = await Zstandard().decompress(compressed!);
      expect(decompressed, equals(data));
    });
  });

  group('Data pattern tests', () {
    ZstandardPlatform? saved;

    setUp(() {
      Zstandard().instance;
      saved = ZstandardPlatform.instance;
      ZstandardPlatform.instance = EchoMockPlatform();
    });

    tearDown(() {
      ZstandardPlatform.instance = saved!;
    });

    test('highly compressible pattern (repeated bytes)', () async {
      final data = Uint8List.fromList(List.filled(1000, 42));
      final compressed = await Zstandard().compress(data, 3);
      expect(compressed, isNotNull);
      expect(compressed!.length, 1000);
    });

    test('sequential data', () async {
      final data = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final compressed = await Zstandard().compress(data, 3);
      expect(compressed, isNotNull);
    });
  });

  group('Concurrent operations', () {
    ZstandardPlatform? saved;

    setUp(() {
      Zstandard().instance;
      saved = ZstandardPlatform.instance;
      ZstandardPlatform.instance = EchoMockPlatform();
    });

    tearDown(() {
      ZstandardPlatform.instance = saved!;
    });

    test('multiple compressions in parallel', () async {
      final futures = List.generate(10, (i) {
        final data = Uint8List.fromList(List.generate(1000, (j) => (i + j) % 256));
        return data.compress(compressionLevel: 3);
      });
      final results = await Future.wait(futures);
      expect(results.every((r) => r != null), isTrue);
      expect(results.length, 10);
    });

    test('compression and decompression interleaved', () async {
      final z = Zstandard();
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final f1 = z.compress(data, 1);
      final f2 = z.compress(data, 3);
      final f3 = z.compress(data, 22);
      final c1 = await f1;
      final c2 = await f2;
      final c3 = await f3;
      expect(c1, isNotNull);
      expect(c2, isNotNull);
      expect(c3, isNotNull);
      final d1 = await z.decompress(c1!);
      final d2 = await z.decompress(c2!);
      expect(d1, equals(data));
      expect(d2, equals(data));
    });
  });
}
