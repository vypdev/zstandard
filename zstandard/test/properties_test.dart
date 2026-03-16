import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiri_check/kiri_check.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:zstandard/zstandard.dart';
import 'package:zstandard_platform_interface/zstandard_platform_interface.dart';

/// Mock platform that implements identity roundtrip for property tests.
class RoundtripMockPlatform with MockPlatformInterfaceMixin implements ZstandardPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('mock');

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

  group('Property-based tests', () {
    property('roundtrip with mock: decompress(compress(x)) == x', () {
      final saved = ZstandardPlatform.instance;
      Zstandard().instance;
      ZstandardPlatform.instance = RoundtripMockPlatform();
      addTearDown(() {
        ZstandardPlatform.instance = saved;
      });
      forAll(
        binary(minLength: 0, maxLength: 2000),
        (List<int> data) async {
          final input = Uint8List.fromList(data);
          final compressed = await Zstandard().compress(input, 3);
          if (compressed == null) return;
          final decompressed = await Zstandard().decompress(compressed);
          expect(decompressed, isNotNull);
          expect(decompressed!.length, input.length);
          expect(List<int>.from(decompressed), data);
        },
        maxExamples: 200,
      );
    });

    property('determinism with mock: same input and level produce same output', () {
      final saved = ZstandardPlatform.instance;
      Zstandard().instance;
      ZstandardPlatform.instance = RoundtripMockPlatform();
      addTearDown(() {
        ZstandardPlatform.instance = saved;
      });
      forAll(
        combine2(
          binary(minLength: 1, maxLength: 500),
          integer(min: 1, max: 22),
        ),
        (tuple) async {
          final data = tuple.$1;
          final level = tuple.$2;
          final input = Uint8List.fromList(data);
          final compressed1 = await Zstandard().compress(input, level);
          final compressed2 = await Zstandard().compress(input, level);
          expect(compressed1, isNotNull);
          expect(compressed2, isNotNull);
          expect(compressed1!.length, compressed2!.length);
          expect(List<int>.from(compressed1), List<int>.from(compressed2));
        },
        maxExamples: 100,
      );
    });
  });
}
