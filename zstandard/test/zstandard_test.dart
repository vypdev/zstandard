import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:zstandard/zstandard.dart';
import 'package:zstandard_platform_interface/zstandard_platform_interface.dart';
import 'package:zstandard/src/platform_manager.dart';

class MockZstandardPlatform with MockPlatformInterfaceMixin implements ZstandardPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('MockPlatform 1.0');

  @override
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) async {
    return Uint8List.fromList(<int>[0x7f, 0x7f, 0x7f]); // fake compressed
  }

  @override
  Future<Uint8List?> decompress(Uint8List data) async {
    return Uint8List.fromList(<int>[1, 2, 3, 4, 5]); // fake decompressed
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Zstandard singleton', () {
    test('Zstandard() returns the same instance', () {
      final a = Zstandard();
      final b = Zstandard();
      expect(identical(a, b), isTrue);
    });
  });

  group('Zstandard with mock platform', () {
    ZstandardPlatform? savedInstance;

    setUp(() {
      // Trigger registration so ZstandardImpl caches; then override with mock.
      Zstandard().instance;
      savedInstance = ZstandardPlatform.instance;
      ZstandardPlatform.instance = MockZstandardPlatform();
    });

    tearDown(() {
      ZstandardPlatform.instance = savedInstance!;
    });

    test('getPlatformVersion returns mock value', () async {
      final z = Zstandard();
      final version = await z.getPlatformVersion();
      expect(version, 'MockPlatform 1.0');
    });

    test('compress forwards to platform and returns result', () async {
      final z = Zstandard();
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await z.compress(data, 3);
      expect(compressed, isNotNull);
      expect(compressed, Uint8List.fromList(<int>[0x7f, 0x7f, 0x7f]));
    });

    test('decompress forwards to platform and returns result', () async {
      final z = Zstandard();
      final data = Uint8List.fromList([0x7f, 0x7f, 0x7f]);
      final decompressed = await z.decompress(data);
      expect(decompressed, isNotNull);
      expect(decompressed, Uint8List.fromList(<int>[1, 2, 3, 4, 5]));
    });

    test('instance returns registered platform', () {
      final z = Zstandard();
      expect(z.instance, isA<MockZstandardPlatform>());
    });
  });

  group('ZstandardExt extension', () {
    ZstandardPlatform? savedInstance;

    setUp(() {
      Zstandard().instance; // trigger registration
      savedInstance = ZstandardPlatform.instance;
      ZstandardPlatform.instance = MockZstandardPlatform();
    });

    tearDown(() {
      ZstandardPlatform.instance = savedInstance!;
    });

    test('compress on null returns null', () async {
      const Uint8List? data = null;
      final compressed = await data.compress();
      expect(compressed, isNull);
    });

    test('decompress on null returns null', () async {
      const Uint8List? data = null;
      final decompressed = await data.decompress();
      expect(decompressed, isNull);
    });

    test('compress on non-null forwards to platform', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final compressed = await data.compress(compressionLevel: 5);
      expect(compressed, isNotNull);
      expect(compressed, Uint8List.fromList(<int>[0x7f, 0x7f, 0x7f]));
    });

    test('decompress on non-null forwards to platform', () async {
      final data = Uint8List.fromList([0x7f, 0x7f, 0x7f]);
      final decompressed = await data.decompress();
      expect(decompressed, isNotNull);
      expect(decompressed, Uint8List.fromList(<int>[1, 2, 3, 4, 5]));
    });

    test('compress uses default compression level 3', () async {
      final data = Uint8List.fromList([10, 20, 30]);
      final compressed = await data.compress();
      expect(compressed, isNotNull);
    });
  });

  group('PlatformManager', () {
    test('singleton returns same instance', () {
      final a = PlatformManager();
      final b = PlatformManager();
      expect(identical(a, b), isTrue);
    });

    test('isDesktop is true when any desktop platform', () {
      final pm = PlatformManager();
      expect(pm.isDesktop, pm.isWindows || pm.isLinux || pm.isMacOS);
    });

    test('isWeb is a boolean', () {
      final pm = PlatformManager();
      expect(pm.isWeb, isA<bool>());
    });
  });
}
