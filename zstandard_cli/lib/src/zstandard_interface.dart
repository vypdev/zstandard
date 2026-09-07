import 'dart:typed_data';

abstract class ZstandardInterface {
  Future<String?> getPlatformVersion();

  Future<Uint8List?> compress(Uint8List data, {int compressionLevel = 3});

  Future<Uint8List?> decompress(
    Uint8List data, {
    int maxOutputSize = 256 * 1024 * 1024,
  });
}
