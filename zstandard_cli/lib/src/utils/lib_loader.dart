import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Returns the path to the zstd native library for the current platform.
/// Exposed for testing; [openZstdLibrary] uses this and opens the library.
String getZstdLibraryPath() {
  if (Platform.isWindows) {
    final String arch = Platform.version.contains('ARM64') ? "arm64" : "x64";
    return path.join(Directory.current.path, 'lib', 'src', 'bin',
        'zstandard_windows_$arch.dll');
  } else if (Platform.isMacOS) {
    return path.join(Directory.current.path, 'lib', 'src', 'bin',
        'libzstandard_macos.dylib');
  } else if (Platform.isLinux) {
    final String arch =
        Platform.operatingSystemVersion.contains("aarch64") ? "arm64" : "x64";
    return path.join(Directory.current.path, 'lib', 'src', 'bin',
        'libzstandard_linux_$arch.so');
  }
  throw UnsupportedError('Unsupported platform');
}

DynamicLibrary openZstdLibrary() {
  return DynamicLibrary.open(getZstdLibraryPath());
}
