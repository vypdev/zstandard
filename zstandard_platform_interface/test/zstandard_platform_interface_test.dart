import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:zstandard_platform_interface/src/zstandard_platform_interface_method_channel.dart';
import 'package:zstandard_platform_interface/zstandard_platform_interface.dart';

class MockZstandardPlatform with MockPlatformInterfaceMixin implements ZstandardPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) async {
    return Uint8List.fromList(<int>[1, 2, 3]); // deterministic for testing
  }

  @override
  Future<Uint8List?> decompress(Uint8List data) async {
    return Uint8List.fromList(<int>[4, 5, 6]); // deterministic for testing
  }
}

class MockB with MockPlatformInterfaceMixin implements ZstandardPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('PlatformB');
  @override
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) =>
      Future.value(Uint8List.fromList([9, 9]));
  @override
  Future<Uint8List?> decompress(Uint8List data) =>
      Future.value(Uint8List.fromList([8, 8]));
}

class OtherMock with MockPlatformInterfaceMixin implements ZstandardPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('Other');
  @override
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) =>
      Future.value(Uint8List.fromList([99]));
  @override
  Future<Uint8List?> decompress(Uint8List data) =>
      Future.value(Uint8List.fromList([100]));
}

void main() {
  group('ZstandardPlatform default instance', () {
    test('MethodChannelZstandardPlatform is the default instance', () {
      final initialPlatform = ZstandardPlatform.instance;
      expect(initialPlatform, isA<MethodChannelZstandardPlatform>());
    });
  });

  group('ZstandardPlatform contract (default implementation)', () {
    late ZstandardPlatform defaultPlatform;

    setUp(() {
      defaultPlatform = MethodChannelZstandardPlatform();
    });

    test('compress throws UnimplementedError', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      await expectLater(
        () async => await defaultPlatform.compress(data, 3),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('decompress throws UnimplementedError', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      await expectLater(
        () async => await defaultPlatform.decompress(data),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('ZstandardPlatform registration and mock', () {
    ZstandardPlatform? savedInstance;

    setUp(() {
      savedInstance = ZstandardPlatform.instance;
    });

    tearDown(() {
      ZstandardPlatform.instance = savedInstance!;
    });

    test('getPlatformVersion returns mock value after registration', () async {
      final mock = MockZstandardPlatform();
      ZstandardPlatform.instance = mock;

      final version = await ZstandardPlatform.instance.getPlatformVersion();
      expect(version, '42');
    });

    test('compress returns mock value after registration', () async {
      final mock = MockZstandardPlatform();
      ZstandardPlatform.instance = mock;

      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await ZstandardPlatform.instance.compress(data, 3);
      expect(compressed, isNotNull);
      expect(compressed, Uint8List.fromList(<int>[1, 2, 3]));
    });

    test('decompress returns mock value after registration', () async {
      final mock = MockZstandardPlatform();
      ZstandardPlatform.instance = mock;

      final data = Uint8List.fromList([1, 2, 3]);
      final decompressed = await ZstandardPlatform.instance.decompress(data);
      expect(decompressed, isNotNull);
      expect(decompressed, Uint8List.fromList(<int>[4, 5, 6]));
    });
  });

  group('Multiple mock platforms', () {
    ZstandardPlatform? savedInstance;

    setUp(() {
      savedInstance = ZstandardPlatform.instance;
    });

    tearDown(() {
      ZstandardPlatform.instance = savedInstance!;
    });

    test('switching platforms at runtime', () async {
      final mockA = MockZstandardPlatform();
      ZstandardPlatform.instance = mockA;
      expect(await ZstandardPlatform.instance.getPlatformVersion(), '42');

      ZstandardPlatform.instance = MockB();
      expect(await ZstandardPlatform.instance.getPlatformVersion(), 'PlatformB');
      final data = Uint8List.fromList([1]);
      final c = await ZstandardPlatform.instance.compress(data, 3);
      expect(c, Uint8List.fromList([9, 9]));
    });

    test('platform A returns different results than platform B', () async {
      ZstandardPlatform.instance = MockZstandardPlatform();
      final data = Uint8List.fromList([1, 2, 3]);
      final compA = await ZstandardPlatform.instance.compress(data, 3);
      expect(compA, Uint8List.fromList([1, 2, 3]));

      ZstandardPlatform.instance = OtherMock();
      final compB = await ZstandardPlatform.instance.compress(data, 3);
      expect(compB, Uint8List.fromList([99]));
    });
  });
}
