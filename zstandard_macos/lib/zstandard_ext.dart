import 'dart:typed_data';

import 'package:zstandard_macos/zstandard_macos.dart';

extension ZstandardExt on Uint8List? {
  Future<Uint8List?> compress({int compressionLevel = 3}) async {
    var data = this;
    if (data == null) return null;
    return ZstandardMacOS().compress(data, compressionLevel);
  }

  Future<Uint8List?> decompress({int maxOutputSize = 256 * 1024 * 1024}) async {
    var data = this;
    if (data == null) return null;
    return ZstandardMacOS().decompressWithOptions(
      data,
      maxOutputSize: maxOutputSize,
    );
  }
}
