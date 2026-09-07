import 'dart:typed_data';

import 'package:zstandard_ios/zstandard_ios.dart';

extension ZstandardExt on Uint8List? {
  Future<Uint8List?> compress({int compressionLevel = 3}) async {
    var data = this;
    if (data == null) return null;
    return ZstandardIOS().compress(data, compressionLevel);
  }

  Future<Uint8List?> decompress({int maxOutputSize = 256 * 1024 * 1024}) async {
    var data = this;
    if (data == null) return null;
    return ZstandardIOS().decompressWithOptions(
      data,
      maxOutputSize: maxOutputSize,
    );
  }
}
