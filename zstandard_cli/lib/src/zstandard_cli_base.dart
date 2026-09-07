import 'dart:typed_data';

import 'package:platform/platform.dart';
import 'package:zstandard_native/zstandard_native.dart';

import 'utils/lib_loader.dart';
import 'zstandard_interface.dart';

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
    if (platform == null) return Future.value('Unknown platform');
    final version = switch (platform.operatingSystem) {
      NativePlatform.macOS => 'macOS ${platform.version}',
      NativePlatform.windows => 'Windows ${platform.version}',
      NativePlatform.linux => 'Linux ${platform.version}',
      _ => 'Unknown platform',
    };
    return Future.value(version);
  }
}
