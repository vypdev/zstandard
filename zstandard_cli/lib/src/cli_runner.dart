import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

import 'utils/constants.dart';
import 'zstandard_cli_base.dart';

/// Version of the command-line interface.
const String zstandardCliVersion = '1.5.0';

/// Runs the compression command and returns a process exit code.
Future<int> runCompressCommand(
  List<String> arguments, {
  Stream<List<int>>? standardInput,
  IOSink? standardOutput,
  IOSink? standardError,
}) =>
    _runCommand(
      _Operation.compress,
      arguments,
      standardInput: standardInput,
      standardOutput: standardOutput,
      standardError: standardError,
    );

/// Runs the decompression command and returns a process exit code.
Future<int> runDecompressCommand(
  List<String> arguments, {
  Stream<List<int>>? standardInput,
  IOSink? standardOutput,
  IOSink? standardError,
}) =>
    _runCommand(
      _Operation.decompress,
      arguments,
      standardInput: standardInput,
      standardOutput: standardOutput,
      standardError: standardError,
    );

enum _Operation { compress, decompress }

final class _CommandOptions {
  _CommandOptions({
    required this.input,
    required this.output,
    required this.force,
    required this.compressionLevel,
    required this.maxOutputSize,
    required this.showHelp,
    required this.showVersion,
  });

  final String? input;
  final String? output;
  final bool force;
  final int compressionLevel;
  final int maxOutputSize;
  final bool showHelp;
  final bool showVersion;
}

Future<int> _runCommand(
  _Operation operation,
  List<String> arguments, {
  Stream<List<int>>? standardInput,
  IOSink? standardOutput,
  IOSink? standardError,
}) async {
  final inputStream = standardInput ?? stdin;
  final outputSink = standardOutput ?? stdout;
  final errorSink = standardError ?? stderr;

  final _CommandOptions options;
  try {
    options = _parseArguments(operation, arguments);
  } on FormatException catch (error) {
    errorSink.writeln('Error: ${error.message}');
    errorSink.writeln(_usage(operation));
    return 2;
  }

  if (options.showHelp) {
    outputSink.writeln(_usage(operation));
    return 0;
  }
  if (options.showVersion) {
    outputSink.writeln('zstandard_cli $zstandardCliVersion');
    return 0;
  }

  final inputPath = options.input!;
  final outputPath = options.output ?? _defaultOutputPath(operation, inputPath);

  if (inputPath != '-' && outputPath != '-') {
    final outputFile = File(outputPath);
    final aliasesInput = outputFile.existsSync() &&
        File(inputPath).existsSync() &&
        FileSystemEntity.identicalSync(inputPath, outputPath);
    if (_samePath(inputPath, outputPath) || aliasesInput) {
      errorSink.writeln(
        'Error: refusing to overwrite the input file. Choose another output '
        'with --output.',
      );
      return 2;
    }
    if (outputFile.existsSync() && !options.force) {
      errorSink.writeln(
        'Error: output already exists: $outputPath (use --force to replace it)',
      );
      return 2;
    }
  }

  try {
    final input = inputPath == '-'
        ? await _readAll(inputStream)
        : await File(inputPath).readAsBytes();
    final cli = ZstandardCLI();
    final Uint8List? result;
    if (operation == _Operation.compress) {
      result = await cli.compress(
        input,
        compressionLevel: options.compressionLevel,
      );
    } else {
      result = await cli.decompress(
        input,
        maxOutputSize: options.maxOutputSize,
      );
    }

    if (result == null) {
      errorSink.writeln(
        'Error: ${operation.name}ion failed. The input may be invalid or the '
        'configured limit may be too small.',
      );
      return 1;
    }

    if (outputPath == '-') {
      outputSink.add(result);
      await outputSink.flush();
    } else {
      await File(outputPath).writeAsBytes(result, flush: true);
      errorSink.writeln(
        '${operation.name}ed ${result.length} bytes to $outputPath',
      );
    }
    return 0;
  } on FileSystemException catch (error) {
    errorSink.writeln(
      'Error: ${error.message}${error.path == null ? '' : ': ${error.path}'}',
    );
    return 1;
  } on Object catch (error) {
    errorSink.writeln('Error: $error');
    return 1;
  }
}

_CommandOptions _parseArguments(_Operation operation, List<String> arguments) {
  String? input;
  String? output;
  var force = false;
  var compressionLevel = 3;
  var maxOutputSize = 256 * 1024 * 1024;
  var showHelp = false;
  var showVersion = false;
  var positionalOnly = false;

  String valueAfter(int index, String option) {
    if (index + 1 >= arguments.length) {
      throw FormatException('$option requires a value');
    }
    return arguments[index + 1];
  }

  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (!positionalOnly && argument == '--') {
      positionalOnly = true;
    } else if (!positionalOnly && (argument == '-h' || argument == '--help')) {
      showHelp = true;
    } else if (!positionalOnly && argument == '--version') {
      showVersion = true;
    } else if (!positionalOnly && (argument == '-f' || argument == '--force')) {
      force = true;
    } else if (!positionalOnly &&
        (argument == '-o' || argument == '--output')) {
      output = valueAfter(index, argument);
      index++;
    } else if (!positionalOnly &&
        operation == _Operation.compress &&
        (argument == '-l' || argument == '--level')) {
      final rawLevel = valueAfter(index, argument);
      compressionLevel = int.tryParse(rawLevel) ??
          (throw FormatException('invalid compression level: $rawLevel'));
      index++;
    } else if (!positionalOnly &&
        operation == _Operation.decompress &&
        (argument == '-m' || argument == '--max-output-size')) {
      final rawLimit = valueAfter(index, argument);
      maxOutputSize = int.tryParse(rawLimit) ??
          (throw FormatException('invalid maximum output size: $rawLimit'));
      index++;
    } else if (!positionalOnly && argument.startsWith('-') && argument != '-') {
      throw FormatException('unknown option: $argument');
    } else if (input == null) {
      input = argument;
    } else {
      throw const FormatException('exactly one input path is required');
    }
  }

  if (!showHelp && !showVersion && input == null) {
    throw const FormatException('an input path or - for stdin is required');
  }
  if (compressionLevel < 1 || compressionLevel > 22) {
    throw const FormatException('compression level must be between 1 and 22');
  }
  if (maxOutputSize <= 0) {
    throw const FormatException(
      'maximum output size must be greater than zero',
    );
  }
  if (input == '-' && output == null) output = '-';

  return _CommandOptions(
    input: input,
    output: output,
    force: force,
    compressionLevel: compressionLevel,
    maxOutputSize: maxOutputSize,
    showHelp: showHelp,
    showVersion: showVersion,
  );
}

String _defaultOutputPath(_Operation operation, String input) {
  if (operation == _Operation.compress) return '$input$extension';
  if (input.endsWith(extension) && input.length > extension.length) {
    return input.substring(0, input.length - extension.length);
  }
  return '$input.out';
}

bool _samePath(String first, String second) =>
    path.equals(path.canonicalize(first), path.canonicalize(second));

Future<Uint8List> _readAll(Stream<List<int>> source) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in source) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

String _usage(_Operation operation) {
  final executable = operation == _Operation.compress
      ? 'zstandard-compress'
      : 'zstandard-decompress';
  final operationOptions = operation == _Operation.compress
      ? '  -l, --level LEVEL           Compression level (1-22; default: 3)\n'
      : '  -m, --max-output-size BYTES Maximum decompressed size (default: 268435456)\n';
  return '''Usage: $executable [options] <input|->

Use - as input to read stdin. Stdin defaults to stdout; file input defaults to
<input>$extension for compression and to the stripped extension (or <input>.out)
for decompression.

Options:
  -o, --output PATH          Output path, or - for stdout
  -f, --force                Replace an existing output file
$operationOptions  -h, --help                 Show this help
      --version              Show the CLI version''';
}
