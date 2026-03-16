import 'dart:io';
import 'dart:typed_data';

import 'package:kiri_check/kiri_check.dart';
import 'package:test/test.dart';
import 'package:zstandard_cli/zstandard_cli.dart';

void main() {
  final bool skipPlatform = !Platform.isMacOS && !Platform.isWindows && !Platform.isLinux;

  group('Property-based tests', () {
    property(
      'roundtrip: decompress(compress(x)) == x',
      () {
        forAll(
          binary(minLength: 0, maxLength: 2000),
          (List<int> data) async {
            if (skipPlatform) return;
            final input = Uint8List.fromList(data);
            final cli = ZstandardCLI();
            final compressed = await cli.compress(input, compressionLevel: 3);
            if (compressed == null) return;
            final decompressed = await cli.decompress(compressed);
            expect(decompressed, isNotNull);
            expect(decompressed!.length, input.length);
            expect(List<int>.from(decompressed), data);
          },
          maxExamples: 200,
        );
      },
      skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : null,
    );

    property(
      'determinism: same input and level produce same compressed output',
      () {
        forAll(
          combine2(
            binary(minLength: 1, maxLength: 500),
            integer(min: 1, max: 22),
          ),
          (tuple) async {
            if (skipPlatform) return;
            final data = tuple.$1;
            final level = tuple.$2;
            final input = Uint8List.fromList(data);
            final cli = ZstandardCLI();
            final compressed1 = await cli.compress(input, compressionLevel: level);
            final compressed2 = await cli.compress(input, compressionLevel: level);
            expect(compressed1, isNotNull);
            expect(compressed2, isNotNull);
            expect(compressed1!.length, compressed2!.length);
            expect(List<int>.from(compressed1), List<int>.from(compressed2));
          },
          maxExamples: 100,
        );
      },
      skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : null,
    );

    property(
      'compression level 22 output size <= level 1 for same input',
      () {
        forAll(
          binary(minLength: 100, maxLength: 1000),
          (List<int> data) async {
            if (skipPlatform) return;
            final input = Uint8List.fromList(data);
            final cli = ZstandardCLI();
            final c1 = await cli.compress(input, compressionLevel: 1);
            final c22 = await cli.compress(input, compressionLevel: 22);
            expect(c1, isNotNull);
            expect(c22, isNotNull);
            expect(c22!.length, lessThanOrEqualTo(c1!.length));
          },
          maxExamples: 50,
        );
      },
      skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : null,
    );
  });
}
