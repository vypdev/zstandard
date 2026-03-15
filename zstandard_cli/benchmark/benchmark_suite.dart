// ignore_for_file: avoid_print
/// Reusable benchmark suite for zstandard_cli. Outputs JSON for regression detection.
/// Run: dart run benchmark/benchmark_suite.dart [--output=path.json]

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:zstandard_cli/zstandard_cli.dart';

class BenchmarkResult {
  final String name;
  final double compressThroughputMBps;
  final double decompressThroughputMBps;
  final int iterations;
  final int dataSizeBytes;
  final int level;

  BenchmarkResult({
    required this.name,
    required this.compressThroughputMBps,
    required this.decompressThroughputMBps,
    required this.iterations,
    required this.dataSizeBytes,
    required this.level,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'compress_throughput_mbps': compressThroughputMBps,
        'decompress_throughput_mbps': decompressThroughputMBps,
        'iterations': iterations,
        'data_size_bytes': dataSizeBytes,
        'level': level,
      };
}

Future<List<BenchmarkResult>> runAll({int runs = 5}) async {
  final cli = ZstandardCLI();
  final sizes = [1024, 64 * 1024, 1024 * 1024];
  final levels = [1, 3, 10, 22];
  final results = <BenchmarkResult>[];

  for (final size in sizes) {
    final data = Uint8List.fromList(List.generate(size, (i) => i % 256));

    for (final level in levels) {
      await cli.compress(data, compressionLevel: level);
      final compressed = await cli.compress(data, compressionLevel: level);
      if (compressed == null) continue;
      final decompressed = await cli.decompress(compressed);
      if (decompressed == null || decompressed.length != data.length) continue;

      int compressSumMs = 0;
      int decompressSumMs = 0;
      for (var i = 0; i < runs; i++) {
        final sw = Stopwatch()..start();
        final c = await cli.compress(data, compressionLevel: level);
        sw.stop();
        compressSumMs += sw.elapsedMilliseconds;
        if (c == null) continue;
        sw.reset();
        sw.start();
        await cli.decompress(c);
        sw.stop();
        decompressSumMs += sw.elapsedMilliseconds;
      }

      final compressMs = compressSumMs / runs;
      final decompressMs = decompressSumMs / runs;
      final sizeMb = size / (1024 * 1024);
      final compressMbS = sizeMb / (compressMs / 1000);
      final decompressMbS = sizeMb / (decompressMs / 1000);
      results.add(BenchmarkResult(
        name: '${size}B_L$level',
        compressThroughputMBps: compressMbS,
        decompressThroughputMBps: decompressMbS,
        iterations: runs,
        dataSizeBytes: size,
        level: level,
      ));
    }
  }
  return results;
}

void main(List<String> args) async {
  final outputIndex = args.indexWhere((a) => a.startsWith('--output='));
  final outputPath = outputIndex >= 0
      ? args[outputIndex].split('=').last
      : 'benchmark_results.json';

  print('Running benchmark suite...');
  final results = await runAll();
  final json = {
    'platform': Platform.operatingSystem,
    'date': DateTime.now().toIso8601String(),
    'results': results.map((r) => r.toJson()).toList(),
  };
  final file = File(outputPath);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  print('Wrote $outputPath');
}
