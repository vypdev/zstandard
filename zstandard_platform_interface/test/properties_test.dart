import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiri_check/kiri_check.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:zstandard_platform_interface/zstandard_platform_interface.dart';

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
  group('Property-based tests', () {
    property('mock roundtrip: decompress(compress(x)) == x', () {
      forAll(
        binary(minLength: 0, maxLength: 500),
        (List<int> data) async {
          final saved = ZstandardPlatform.instance;
          ZstandardPlatform.instance = RoundtripMockPlatform();
          try {
            final input = Uint8List.fromList(data);
            final compressed = await ZstandardPlatform.instance.compress(input, 3);
            expect(compressed, isNotNull);
            final decompressed = await ZstandardPlatform.instance.decompress(compressed!);
            expect(decompressed, isNotNull);
            expect(List<int>.from(decompressed!), data);
          } finally {
            ZstandardPlatform.instance = saved;
          }
        },
        maxExamples: 100,
      );
    });
  });
}
