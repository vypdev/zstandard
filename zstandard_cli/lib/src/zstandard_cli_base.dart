import 'dart:typed_data';

import 'package:platform/platform.dart';
import 'package:zstandard_native/zstandard_native.dart';

import 'utils/lib_loader.dart';
import 'zstandard_interface.dart';

/// Formats a native platform version without consulting host state.
///
/// This internal helper keeps all platform branches deterministic in tests.
String zstdPlatformVersion(String? operatingSystem, String? version) {
  if (operatingSystem == null) return 'Unknown platform';
  return switch (operatingSystem) {
    NativePlatform.macOS => 'macOS $version',
    NativePlatform.windows => 'Windows $version',
    NativePlatform.linux => 'Linux $version',
    _ => 'Unknown platform',
  };
}

/// Command-line and in-code Zstandard compression for desktop Dart.
class ZstandardCLI implements ZstandardInterface {
  static final Future<ZstandardNativeCodec> _sharedCodec = _loadCodec();

  static Future<ZstandardNativeCodec> _loadCodec() async =>
      ZstandardNativeCodec(ZstandardNativeBindings(await openZstdLibrary()));

  @override
  Future<Uint8List?> compress(
    Uint8List data, {
    int compressionLevel = 3,
  }) async =>
      (await _sharedCodec).compress(data, compressionLevel);

  @override
  Future<Uint8List?> decompress(
    Uint8List data, {
    int maxOutputSize = nativeDefaultMaxDecompressedSize,
  }) async =>
      (await _sharedCodec).decompress(data, maxOutputSize: maxOutputSize);

  @override
  Future<String?> getPlatformVersion() {
    final platform = NativePlatform.current;
    return Future.value(
      zstdPlatformVersion(platform?.operatingSystem, platform?.version),
    );
  }
}
