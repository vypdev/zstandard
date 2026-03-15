import 'dart:typed_data';

import 'package:zstandard_cli/src/zstandard_cli_base.dart';

/// Extension methods on [Uint8List?] for Zstandard compression and decompression (CLI).
///
/// When the receiver is null, both [compress] and [decompress] return null.
/// Uses [ZstandardCLI] under the hood. Only supported on macOS, Windows, and Linux.
extension ZstandardExt on Uint8List? {
  /// Compresses this byte list using the given [compressionLevel] (default 3).
  ///
  /// Returns null if the receiver is null or compression failed.
  Future<Uint8List?> compress({int compressionLevel = 3}) async {
    var data = this;
    if (data == null) return null;
    return ZstandardCLI().compress(data, compressionLevel: compressionLevel);
  }

  /// Decompresses this byte list (must be Zstandard-compressed data).
  ///
  /// Returns null if the receiver is null or decompression failed.
  Future<Uint8List?> decompress() async {
    var data = this;
    if (data == null) return null;
    return ZstandardCLI().decompress(data);
  }
}
