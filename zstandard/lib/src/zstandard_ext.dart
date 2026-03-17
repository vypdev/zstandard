import 'dart:typed_data';

import 'package:zstandard/zstandard.dart';

/// Extension methods on [Uint8List?] for Zstandard compression and decompression.
///
/// When the receiver is null, both [compress] and [decompress] return null
/// without calling the platform.
///
/// Example:
/// ```dart
/// final compressed = await data.compress(compressionLevel: 5);
/// final decompressed = await compressed?.decompress();
/// ```
extension ZstandardExt on Uint8List? {
  /// Compresses this byte list using the given [compressionLevel].
  ///
  /// Default [compressionLevel] is 3. Range is 1–22.
  /// Returns null if the receiver is null or compression failed.
  Future<Uint8List?> compress({int compressionLevel = 3}) async {
    var data = this;
    if (data == null) return null;
    return Zstandard().compress(data, compressionLevel);
  }

  /// Decompresses this byte list (must be Zstandard-compressed data).
  ///
  /// Returns null if the receiver is null or decompression failed.
  Future<Uint8List?> decompress() async {
    var data = this;
    if (data == null) return null;
    return Zstandard().decompress(data);
  }
}
