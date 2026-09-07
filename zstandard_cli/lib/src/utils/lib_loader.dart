import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;

/// Returns the bundled library name for a platform and ABI.
///
/// Optional arguments keep platform selection deterministic in tests. This is
/// an internal `src` API; production callers should omit them.
String zstdLibraryFileName({String? operatingSystem, Abi? abi}) {
  final selectedOperatingSystem = operatingSystem ?? Platform.operatingSystem;
  final selectedAbi = abi ?? Abi.current();
  if (selectedOperatingSystem == 'windows') {
    return switch (selectedAbi) {
      Abi.windowsArm64 => 'zstandard_windows_arm64.dll',
      Abi.windowsX64 => 'zstandard_windows_x64.dll',
      _ => throw UnsupportedError('Unsupported Windows ABI: $selectedAbi'),
    };
  }
  if (selectedOperatingSystem == 'macos') return 'libzstandard_macos.dylib';
  if (selectedOperatingSystem == 'linux') {
    return switch (selectedAbi) {
      Abi.linuxArm64 => 'libzstandard_linux_arm64.so',
      Abi.linuxX64 => 'libzstandard_linux_x64.so',
      _ => throw UnsupportedError('Unsupported Linux ABI: $selectedAbi'),
    };
  }
  throw UnsupportedError('Unsupported platform: $selectedOperatingSystem');
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
      zstdLibraryFileName(),
    );

/// Resolves the shipped native library from the active package configuration.
///
/// `ZSTANDARD_CLI_LIBRARY` may point to an explicitly managed library for AOT
/// deployments that do not ship package sources next to the executable.
Future<String> resolveZstdLibraryPath({
  Map<String, String>? environment,
  Iterable<Uri>? packageConfigs,
  String? executableDirectory,
  String? legacyPackageRoot,
}) async {
  final override =
      (environment ?? Platform.environment)['ZSTANDARD_CLI_LIBRARY'];
  if (override != null && override.isNotEmpty) {
    if (File(override).existsSync()) return path.normalize(override);
    throw ArgumentError.value(
      override,
      'ZSTANDARD_CLI_LIBRARY',
      'Native library does not exist',
    );
  }

  for (final packageConfig
      in packageConfigs ?? await zstdPackageConfigCandidates()) {
    final candidate = await resolveZstdLibraryFromPackageConfig(packageConfig);
    if (candidate != null && File(candidate).existsSync()) {
      return path.normalize(candidate);
    }
  }

  final executableCandidate = path.join(
    executableDirectory ?? File(Platform.resolvedExecutable).parent.path,
    zstdLibraryFileName(),
  );
  if (File(executableCandidate).existsSync()) {
    return path.normalize(executableCandidate);
  }

  final legacyCandidate = getZstdLibraryPath(packageRoot: legacyPackageRoot);
  if (File(legacyCandidate).existsSync()) {
    return path.normalize(legacyCandidate);
  }

  throw StateError(
    'Unable to locate ${zstdLibraryFileName()}. Set ZSTANDARD_CLI_LIBRARY to '
    'an absolute native-library path for compiled deployments.',
  );
}

/// Opens the shipped or explicitly configured zstd library.
Future<DynamicLibrary> openZstdLibrary() async =>
    DynamicLibrary.open(await resolveZstdLibraryPath());

/// Returns package-config candidates visible to the current Dart process.
///
/// Optional arguments expose otherwise host-controlled inputs to internal
/// tests without changing production resolution behavior.
Future<List<Uri>> zstdPackageConfigCandidates({
  List<String>? executableArguments,
  Future<Uri?> Function()? isolatePackageConfigProvider,
}) async {
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

  final arguments = executableArguments ?? Platform.executableArguments;
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument.startsWith('--packages=')) {
      addPath(argument.substring('--packages='.length));
    } else if (argument == '--packages' && index + 1 < arguments.length) {
      addPath(arguments[++index]);
    }
  }

  try {
    add(
      isolatePackageConfigProvider == null
          ? await Isolate.packageConfig
          : await isolatePackageConfigProvider(),
    );
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

/// Resolves the CLI library path declared by one package configuration.
///
/// Exposed from this internal `src` library for deterministic parser tests.
Future<String?> resolveZstdLibraryFromPackageConfig(
  Uri configUri, {
  Future<String> Function(File)? readConfig,
}) async {
  final configFile = File.fromUri(configUri);
  if (!configFile.existsSync()) return null;

  try {
    final config = jsonDecode(
      await (readConfig ?? (file) => file.readAsString())(configFile),
    );
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
        zstdLibraryFileName(),
      );
    }
  } on FormatException {
    return null;
  } on FileSystemException {
    return null;
  }

  return null;
}
