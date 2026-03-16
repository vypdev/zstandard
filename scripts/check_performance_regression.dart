// ignore_for_file: avoid_print
/// Checks benchmark results against a baseline. Fails if throughput regresses beyond threshold.
/// Usage: dart run scripts/check_performance_regression.dart --baseline=path/baseline.json --current=path/current.json [--threshold=0.10]
/// Threshold is the allowed fractional regression (default 0.10 = 10%).

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  String? baselinePath;
  String? currentPath;
  double threshold = 0.10;

  for (final arg in args) {
    if (arg.startsWith('--baseline=')) {
      baselinePath = arg.split('=').last;
    } else if (arg.startsWith('--current=')) {
      currentPath = arg.split('=').last;
    } else if (arg.startsWith('--threshold=')) {
      threshold = double.tryParse(arg.split('=').last) ?? 0.10;
    }
  }

  if (baselinePath == null || currentPath == null) {
    print('Usage: dart run scripts/check_performance_regression.dart --baseline=BASELINE.json --current=CURRENT.json [--threshold=0.10]');
    exit(1);
  }

  final baselineFile = File(baselinePath);
  final currentFile = File(currentPath);
  if (!baselineFile.existsSync()) {
    print('Baseline file not found: $baselinePath');
    exit(1);
  }
  if (!currentFile.existsSync()) {
    print('Current file not found: $currentPath');
    exit(1);
  }

  final baseline = jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;
  final current = jsonDecode(currentFile.readAsStringSync()) as Map<String, dynamic>;

  final baselineResults = (baseline['results'] as List).cast<Map<String, dynamic>>();
  final currentResults = (current['results'] as List).cast<Map<String, dynamic>>();

  if (baselineResults.length != currentResults.length) {
    print('Result count mismatch: baseline ${baselineResults.length}, current ${currentResults.length}');
    exit(1);
  }

  var failed = false;
  for (var i = 0; i < baselineResults.length; i++) {
    final name = baselineResults[i]['name'] as String;
    final baseCompress = (baselineResults[i]['compress_throughput_mbps'] as num).toDouble();
    final baseDecompress = (baselineResults[i]['decompress_throughput_mbps'] as num).toDouble();
    final currCompress = (currentResults[i]['compress_throughput_mbps'] as num).toDouble();
    final currDecompress = (currentResults[i]['decompress_throughput_mbps'] as num).toDouble();

    final compressRegress = baseCompress > 0 ? (baseCompress - currCompress) / baseCompress : 0.0;
    final decompressRegress = baseDecompress > 0 ? (baseDecompress - currDecompress) / baseDecompress : 0.0;

    if (compressRegress > threshold) {
      print('REGRESSION $name: compress ${currCompress.toStringAsFixed(2)} MB/s (baseline $baseCompress, ${(compressRegress * 100).toStringAsFixed(1)}% regression)');
      failed = true;
    }
    if (decompressRegress > threshold) {
      print('REGRESSION $name: decompress ${currDecompress.toStringAsFixed(2)} MB/s (baseline $baseDecompress, ${(decompressRegress * 100).toStringAsFixed(1)}% regression)');
      failed = true;
    }
  }

  if (failed) {
    print('Performance regression detected (threshold ${(threshold * 100).toInt()}%)');
    exit(1);
  }
  print('No performance regression detected.');
}
