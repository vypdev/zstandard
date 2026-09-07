// ignore_for_file: avoid_print
/// Compression and decompression benchmark for zstandard_cli.
///
/// Run from package root: dart run benchmark/compression_benchmark.dart
///
/// Use for regression detection: run before/after changes and compare
/// throughput (MB/s) and roundtrip correctness.
library;

import 'dart:typed_data';

import 'package:zstandard_cli/zstandard_cli.dart';

void main() async {
  final cli = ZstandardCLI();
  final sizes = [1024, 64 * 1024, 1024 * 1024]; // 1KB, 64KB, 1MB
  final levels = [1, 3, 10, 22];
  final results = <String, String>{};

  print('Zstandard CLI benchmark');
  print('======================\n');

  for (final size in sizes) {
    final data = Uint8List.fromList(List.generate(size, (i) => i % 256));

    for (final level in levels) {
      // Warm-up
      await cli.compress(data, compressionLevel: level);
      final compressed = await cli.compress(data, compressionLevel: level);
      if (compressed == null) {
        print('ERROR: compress returned null (size=$size, level=$level)');
        continue;
      }
      final decompressed = await cli.decompress(compressed);
      if (decompressed == null || decompressed.length != data.length) {
        print('ERROR: roundtrip failed (size=$size, level=$level)');
        continue;
      }

      // Timed runs
      const runs = 5;
      var compressSumUs = 0;
      var decompressSumUs = 0;
      for (var i = 0; i < runs; i++) {
        final sw = Stopwatch()..start();
        final c = await cli.compress(data, compressionLevel: level);
        sw.stop();
        compressSumUs +=
            sw.elapsedMicroseconds == 0 ? 1 : sw.elapsedMicroseconds;
        if (c == null) {
          throw StateError('Compression failed for ${size}B at level $level');
        }
        sw.reset();
        sw.start();
        final d = await cli.decompress(c);
        sw.stop();
        decompressSumUs +=
            sw.elapsedMicroseconds == 0 ? 1 : sw.elapsedMicroseconds;
        if (d == null || !_bytesEqual(d, data)) {
          throw StateError('Roundtrip failed for ${size}B at level $level');
        }
      }

      final compressSeconds =
          compressSumUs / runs / Duration.microsecondsPerSecond;
      final decompressSeconds =
          decompressSumUs / runs / Duration.microsecondsPerSecond;
      final sizeMb = size / (1024 * 1024);
      final compressMbS = sizeMb / compressSeconds;
      final decompressMbS = sizeMb / decompressSeconds;
      final key = '${size}B_L$level';
      results[key] =
          'compress ${compressMbS.toStringAsFixed(2)} MB/s, decompress ${decompressMbS.toStringAsFixed(2)} MB/s';
      print('$key: ${results[key]}');
    }
    print('');
  }

  print('Done. Use these numbers as baseline for regression detection.');
}

bool _bytesEqual(Uint8List first, Uint8List second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
