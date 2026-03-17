import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:zstandard/zstandard.dart';
import 'package:zstandard_platform_interface/zstandard_platform_interface.dart';

/// Mock that returns null for decompress (simulates corrupted/invalid input).
class MockDecompressFails with MockPlatformInterfaceMixin implements ZstandardPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('Mock 1.0');

  @override
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) async {
    return Uint8List.fromList([0x28, 0xb5, 0x2f, 0xfd, 0x00, 0x00, 0x01, 0x00, 0x00]);
  }

  @override
  Future<Uint8List?> decompress(Uint8List data) async => null;
}

/// Mock that returns null for compress (simulates compression failure).
class MockCompressFails with MockPlatformInterfaceMixin implements ZstandardPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('Mock 1.0');

  @override
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) async => null;

  @override
  Future<Uint8List?> decompress(Uint8List data) async =>
      Future.value(Uint8List.fromList([1, 2, 3]));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Error handling — decompress returns null', () {
    ZstandardPlatform? saved;

    setUp(() {
      Zstandard().instance;
      saved = ZstandardPlatform.instance;
      ZstandardPlatform.instance = MockDecompressFails();
    });

    tearDown(() {
      ZstandardPlatform.instance = saved!;
    });

    test('decompress invalid data returns null', () async {
      final z = Zstandard();
      final corrupted = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await z.decompress(corrupted);
      expect(result, isNull);
    });

    test('extension decompress on invalid data returns null', () async {
      final corrupted = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await corrupted.decompress();
      expect(result, isNull);
    });
  });

  group('Error handling — compress returns null', () {
    ZstandardPlatform? saved;

    setUp(() {
      Zstandard().instance;
      saved = ZstandardPlatform.instance;
      ZstandardPlatform.instance = MockCompressFails();
    });

    tearDown(() {
      ZstandardPlatform.instance = saved!;
    });

    test('compress failure returns null', () async {
      final z = Zstandard();
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await z.compress(data, 3);
      expect(result, isNull);
    });

    test('extension compress failure returns null', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await data.compress(compressionLevel: 3);
      expect(result, isNull);
    });
  });

  group('Edge cases — null and empty', () {
    ZstandardPlatform? saved;

    setUp(() {
      Zstandard().instance;
      saved = ZstandardPlatform.instance;
      ZstandardPlatform.instance = MockDecompressFails();
    });

    tearDown(() {
      ZstandardPlatform.instance = saved!;
    });

    test('extension compress on null returns null', () async {
      const Uint8List? data = null;
      expect(await data.compress(), isNull);
    });

    test('extension decompress on null returns null', () async {
      const Uint8List? data = null;
      expect(await data.decompress(), isNull);
    });
  });
}
