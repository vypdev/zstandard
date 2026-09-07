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

/// Resolves the shipped native library from the package URI.
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

  final packageUri = await Isolate.resolvePackageUri(
    Uri.parse('package:zstandard_cli/zstandard_cli.dart'),
  );
  if (packageUri != null && packageUri.scheme == 'file') {
    final packageLib = File.fromUri(packageUri).parent.path;
    final candidate = path.join(packageLib, 'src', 'bin', _libraryFileName());
    if (File(candidate).existsSync()) return path.normalize(candidate);
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
