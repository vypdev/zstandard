import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;

String _libraryFileName() {
  final abi = Abi.current();
  if (Platform.isWindows) {
    return switch (abi) {
      Abi.windowsArm64 => 'zstandard_windows_arm64.dll',
      Abi.windowsX64 => 'zstandard_windows_x64.dll',
      _ => throw UnsupportedError('Unsupported Windows ABI: $abi'),
    };
  }
  if (Platform.isMacOS) return 'libzstandard_macos.dylib';
  if (Platform.isLinux) {
    return switch (abi) {
      Abi.linuxArm64 => 'libzstandard_linux_arm64.so',
      Abi.linuxX64 => 'libzstandard_linux_x64.so',
      _ => throw UnsupportedError('Unsupported Linux ABI: $abi'),
    };
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

/// Returns the legacy package-relative native library path.
///
/// Prefer [resolveZstdLibraryPath], which is independent of the current
/// working directory. [packageRoot] exists for deterministic tests.
String getZstdLibraryPath({String? packageRoot}) => path.join(
      packageRoot ?? Directory.current.path,
      'lib',
      'src',
      'bin',
      _libraryFileName(),
    );

/// Resolves the shipped native library from the active package configuration.
///
/// `ZSTANDARD_CLI_LIBRARY` may point to an explicitly managed library for AOT
/// deployments that do not ship package sources next to the executable.
Future<String> resolveZstdLibraryPath() async {
  final override = Platform.environment['ZSTANDARD_CLI_LIBRARY'];
  if (override != null && override.isNotEmpty) {
    if (File(override).existsSync()) return path.normalize(override);
    throw ArgumentError.value(
      override,
      'ZSTANDARD_CLI_LIBRARY',
      'Native library does not exist',
    );
  }

  for (final packageConfig in await _packageConfigCandidates()) {
    final candidate = await _resolveFromPackageConfig(packageConfig);
    if (candidate != null && File(candidate).existsSync()) {
      return path.normalize(candidate);
    }
  }

  final executableCandidate = path.join(
    File(Platform.resolvedExecutable).parent.path,
    _libraryFileName(),
  );
  if (File(executableCandidate).existsSync()) {
    return path.normalize(executableCandidate);
  }

  final legacyCandidate = getZstdLibraryPath();
  if (File(legacyCandidate).existsSync()) {
    return path.normalize(legacyCandidate);
  }

  throw StateError(
    'Unable to locate ${_libraryFileName()}. Set ZSTANDARD_CLI_LIBRARY to '
    'an absolute native-library path for compiled deployments.',
  );
}

/// Opens the shipped or explicitly configured zstd library.
Future<DynamicLibrary> openZstdLibrary() async =>
    DynamicLibrary.open(await resolveZstdLibraryPath());

Future<List<Uri>> _packageConfigCandidates() async {
  final candidates = <Uri>[];
  final seen = <String>{};

  void add(Uri? uri) {
    if (uri == null || uri.scheme != 'file' || !seen.add(uri.toString())) {
      return;
    }
    candidates.add(uri);
  }

  void addPath(String configuredPath) {
    final parsed = Uri.tryParse(configuredPath);
    add(
      parsed != null && parsed.scheme.isNotEmpty
          ? parsed
          : File(configuredPath).absolute.uri,
    );
  }

  final configuredPath = Platform.packageConfig;
  if (configuredPath != null && configuredPath.isNotEmpty) {
    addPath(configuredPath);
  }

  final executableArguments = Platform.executableArguments;
  for (var index = 0; index < executableArguments.length; index++) {
    final argument = executableArguments[index];
    if (argument.startsWith('--packages=')) {
      addPath(argument.substring('--packages='.length));
    } else if (argument == '--packages' &&
        index + 1 < executableArguments.length) {
      addPath(executableArguments[++index]);
    }
  }

  try {
    add(await Isolate.packageConfig);
  } on UnsupportedError {
    // Some embedders, including flutter_tester, do not expose this VM API.
  }

  if (Platform.script.scheme == 'file') {
    _addAncestorPackageConfigs(File.fromUri(Platform.script).parent, add);
  }
  _addAncestorPackageConfigs(Directory.current, add);

  return candidates;
}

void _addAncestorPackageConfigs(Directory start, void Function(Uri) add) {
  var directory = start.absolute;
  while (true) {
    final packageConfig = File(
      path.join(directory.path, '.dart_tool', 'package_config.json'),
    );
    if (packageConfig.existsSync()) add(packageConfig.uri);

    final parent = directory.parent;
    if (parent.path == directory.path) return;
    directory = parent;
  }
}

Future<String?> _resolveFromPackageConfig(Uri configUri) async {
  final configFile = File.fromUri(configUri);
  if (!configFile.existsSync()) return null;

  try {
    final config = jsonDecode(await configFile.readAsString());
    if (config is! Map<String, Object?>) return null;
    final packages = config['packages'];
    if (packages is! List<Object?>) return null;

    for (final package in packages) {
      if (package is! Map<String, Object?> ||
          package['name'] != 'zstandard_cli') {
        continue;
      }
      final rootValue = package['rootUri'];
      final packageValue = package['packageUri'];
      if (rootValue is! String || packageValue is! String) return null;

      var rootUri = configUri.resolve(rootValue);
      if (!rootUri.path.endsWith('/')) {
        rootUri = rootUri.replace(path: '${rootUri.path}/');
      }
      final packageLibUri = rootUri.resolve(packageValue);
      if (packageLibUri.scheme != 'file') return null;

      return path.join(
        Directory.fromUri(packageLibUri).path,
        'src',
        'bin',
        _libraryFileName(),
      );
    }
  } on FormatException {
    return null;
  } on FileSystemException {
    return null;
  }

  return null;
}
