import 'dart:io';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart scripts/check_lcov_coverage.dart <lcov.info> <threshold>',
    );
    exitCode = 2;
    return;
  }

  final coverageFile = File(arguments[0]);
  final threshold = double.tryParse(arguments[1]);
  if (!coverageFile.existsSync()) {
    stderr.writeln('Coverage file does not exist: ${coverageFile.path}');
    exitCode = 2;
    return;
  }
  if (threshold == null ||
      !threshold.isFinite ||
      threshold < 0 ||
      threshold > 100) {
    stderr.writeln('Coverage threshold must be a number from 0 to 100.');
    exitCode = 2;
    return;
  }

  var hit = 0;
  var found = 0;
  for (final line in coverageFile.readAsLinesSync()) {
    if (!line.startsWith('DA:')) continue;
    final fields = line.substring(3).split(',');
    if (fields.length < 2) continue;
    final count = int.tryParse(fields[1]);
    if (count == null) continue;
    found++;
    if (count > 0) hit++;
  }

  if (found == 0) {
    stderr.writeln(
      'Coverage file contains no line records: ${coverageFile.path}',
    );
    exitCode = 2;
    return;
  }

  final coverage = hit * 100 / found;
  stdout.writeln(
    'Line coverage: ${coverage.toStringAsFixed(2)}% ($hit/$found; '
    'required ${threshold.toStringAsFixed(2)}%)',
  );
  if (coverage + 1e-9 < threshold) {
    stderr.writeln('Coverage is below the required threshold.');
    exitCode = 1;
  }
}
