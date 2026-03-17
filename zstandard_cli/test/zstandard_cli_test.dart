import 'dart:io';
import 'dart:typed_data';

import 'package:leak_tracker/leak_tracker.dart';
import 'package:leak_tracker_testing/leak_tracker_testing.dart';
import 'package:test/test.dart';
import 'package:zstandard_cli/zstandard_cli.dart';
import 'package:zstandard_cli/src/utils/constants.dart';
import 'package:zstandard_cli/src/utils/lib_loader.dart';

void main() {
  final bool skipPlatform = !Platform.isMacOS && !Platform.isWindows && !Platform.isLinux;

  setUpAll(() {
    if (!LeakTracking.isStarted) {
      LeakTracking.start();
    }
  });

  group('Zstandard CLI tests', () {
    test('getPlatformVersion returns non-null string on supported platform', () async {
      if (skipPlatform) return;
      final cli = ZstandardCLI();
      final version = await cli.getPlatformVersion();
      expect(version, isNotNull);
      expect(version, isNotEmpty);
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('getPlatformVersion starts with platform name', () async {
      if (skipPlatform) return;
      final cli = ZstandardCLI();
      final version = await cli.getPlatformVersion();
      if (Platform.isMacOS) {
        expect(version, startsWith('macOS '));
      } else if (Platform.isWindows) {
        expect(version, startsWith('Windows '));
      } else if (Platform.isLinux) {
        expect(version, startsWith('Linux '));
      }
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('getZstdLibraryPath returns path with lib/src/bin and platform extension', () {
      if (skipPlatform) return;
      final libPath = getZstdLibraryPath();
      expect(libPath, contains('lib'));
      expect(libPath, contains('src'));
      expect(libPath, contains('bin'));
      if (Platform.isWindows) {
        expect(libPath, endsWith('.dll'));
        expect(libPath, anyOf(contains('arm64'), contains('x64')));
      } else if (Platform.isMacOS) {
        expect(libPath, endsWith('.dylib'));
      } else if (Platform.isLinux) {
        expect(libPath, endsWith('.so'));
        expect(libPath, anyOf(contains('arm64'), contains('x64')));
      }
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('ZstandardCLI can be instantiated on supported platform', () {
      if (skipPlatform) return;
      expect(ZstandardCLI(), isA<ZstandardCLI>());
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);
    test('Compress and decompress small Uint8List', () async {
      final Uint8List sample = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress large Uint8List', () async {
      final Uint8List sample =
          Uint8List.fromList(List<int>.generate(100000, (i) => i % 256));
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress empty Uint8List', () async {
      final Uint8List sample = Uint8List(0);
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(sample, equals(compressed));
      expect(sample.length, equals(compressed?.length));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress Uint8List with repeated values', () async {
      final Uint8List sample = Uint8List.fromList(List.filled(1000, 42));
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress with maximum compression level', () async {
      final Uint8List sample =
          Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final compressed = await sample.compress(compressionLevel: 22);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress with minimal compression level', () async {
      final Uint8List sample =
          Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final compressed = await sample.compress(compressionLevel: 1);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress with level 22 produces valid decompressible output', () async {
      final Uint8List sample = Uint8List.fromList(List.filled(500, 7));
      final compressed = await sample.compress(compressionLevel: 22);
      expect(compressed, isNotNull);
      final decompressed = await compressed!.decompress();
      expect(decompressed, equals(sample));
    });

    test('Null extension receiver returns null from compress', () async {
      const Uint8List? nullData = null;
      final result = await nullData.compress();
      expect(result, isNull);
    });

    test('Null extension receiver returns null from decompress', () async {
      const Uint8List? nullData = null;
      final result = await nullData.decompress();
      expect(result, isNull);
    });

    test('decompress corrupted data returns null', () async {
      if (skipPlatform) return;
      final corrupted = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final cli = ZstandardCLI();
      final result = await cli.decompress(corrupted);
      expect(result, isNull);
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('decompress random bytes returns null', () async {
      if (skipPlatform) return;
      final random = Uint8List.fromList(List.generate(64, (i) => (i * 31) % 256));
      final cli = ZstandardCLI();
      final result = await cli.decompress(random);
      expect(result, isNull);
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('compress and decompress do not leak', () async {
      if (skipPlatform) return;
      final cli = ZstandardCLI();
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await cli.compress(data, compressionLevel: 3);
      expect(compressed, isNotNull);
      final decompressed = await cli.decompress(compressed!);
      expect(decompressed, equals(data));
      if (LeakTracking.isStarted) {
        final leaks = await LeakTracking.collectLeaks();
        expect(leaks, isLeakFree);
      }
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('file roundtrip: write, compress, decompress, compare', () async {
      if (skipPlatform) return;
      final tempDir = await Directory.systemTemp.createTemp('zstd_cli_test');
      final file = File('${tempDir.path}/input.bin');
      final data = Uint8List.fromList(List.generate(500, (i) => i % 256));
      await file.writeAsBytes(data);
      final cli = ZstandardCLI();
      final compressed = await cli.compress(data, compressionLevel: 3);
      expect(compressed, isNotNull);
      final compressedFile = File('${tempDir.path}/output$extension');
      await compressedFile.writeAsBytes(compressed!);
      final readBack = await compressedFile.readAsBytes();
      final decompressed = await cli.decompress(Uint8List.fromList(readBack));
      expect(decompressed, equals(data));
      await tempDir.delete(recursive: true);
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('multiple compressions in parallel', () async {
      if (skipPlatform) return;
      final cli = ZstandardCLI();
      final futures = List.generate(5, (i) {
        final data = Uint8List.fromList(List.generate(200, (j) => (i + j) % 256));
        return cli.compress(data, compressionLevel: 3);
      });
      final results = await Future.wait(futures);
      expect(results.every((r) => r != null), isTrue);
      for (var i = 0; i < results.length; i++) {
        final decompressed = await cli.decompress(results[i]!);
        final original = Uint8List.fromList(List.generate(200, (j) => (i + j) % 256));
        expect(decompressed, equals(original));
      }
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);
  });
}
