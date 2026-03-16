// ignore_for_file: avoid_print
/// Generates a simple quality summary from coverage and test results.
/// Usage: dart run scripts/generate_quality_report.dart
/// Reads coverage_all/*.lcov.info if present and writes quality_summary.md

import 'dart:io';

void main() {
  final root = Directory.current.path;
  final coverageDir = Directory('$root/coverage_all');
  final buffer = StringBuffer();
  buffer.writeln('# Quality Summary');
  buffer.writeln('');
  buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
  buffer.writeln('');

  if (coverageDir.existsSync()) {
    buffer.writeln('## Coverage');
    buffer.writeln('');
    for (final f in coverageDir.listSync()) {
      if (f is File && f.path.endsWith('.lcov.info')) {
        final name = f.uri.pathSegments.last.replaceAll('.lcov.info', '');
        buffer.writeln('- $name: lcov collected');
      }
    }
  } else {
    buffer.writeln('## Coverage');
    buffer.writeln('');
    buffer.writeln('Run `./scripts/collect_all_coverage.sh` first.');
  }

  buffer.writeln('');
  buffer.writeln('## Test Packages');
  buffer.writeln('');
  final packages = [
    'zstandard', 'zstandard_platform_interface', 'zstandard_android',
    'zstandard_ios', 'zstandard_macos', 'zstandard_linux', 'zstandard_windows',
    'zstandard_web', 'zstandard_cli'
  ];
  for (final p in packages) {
    final testDir = Directory('$root/$p/test');
    final pubspec = File('$root/$p/pubspec.yaml');
    if (pubspec.existsSync()) {
      buffer.writeln('- $p: ${testDir.existsSync() ? "has test/" : "no test/"}');
    }
  }

  File('$root/quality_summary.md').writeAsStringSync(buffer.toString());
  print('Wrote quality_summary.md');
}
