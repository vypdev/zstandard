import 'dart:typed_data';

import 'package:zstandard/src/zstandard_impl_web.dart'
    if (dart.library.io) 'package:zstandard/src/zstandard_impl_native.dart';
import 'package:zstandard_platform_interface/zstandard_platform_interface.dart';

export 'src/zstandard_ext.dart';

/// Main entry point for Zstandard compression and decompression in Flutter.
///
/// Use [Zstandard] to compress and decompress [Uint8List] data on all supported
/// platforms (Android, iOS, macOS, Windows, Linux, web). The implementation
/// is selected automatically based on the current platform.
///
/// Example:
/// ```dart
/// final zstandard = Zstandard();
/// final compressed = await zstandard.compress(data, 3);
/// final decompressed = await zstandard.decompress(compressed!);
/// ```
///
/// See also [ZstandardExt] for extension methods on [Uint8List?].
class Zstandard {
  static Zstandard? _instance;

  Zstandard._internal();

  /// Creates or returns the singleton [Zstandard] instance.
  factory Zstandard() {
    _instance ??= Zstandard._internal();
    return _instance!;
  }

  /// The currently registered platform implementation.
  ///
  /// Typically used only for testing (e.g. to set a mock) or to call
  /// [getPlatformVersion]. Prefer [compress] and [decompress] for normal use.
  ZstandardPlatform get instance => ZstandardImpl().instance;

  /// Returns a platform-specific version or identifier string.
  ///
  /// May be null if the platform does not provide one. Useful for debugging
  /// or display (e.g. "Android 14", "macOS 14.0").
  Future<String?> getPlatformVersion() => instance.getPlatformVersion();

  /// Compresses [data] using Zstandard with the given [compressionLevel].
  ///
  /// [compressionLevel] must be between 1 (fastest) and 22 (best ratio).
  /// Returns the compressed bytes, or null if compression failed.
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) =>
      instance.compress(data, compressionLevel);

  /// Decompresses Zstandard-compressed [data].
  ///
  /// Returns the decompressed bytes, or null if decompression failed
  /// (e.g. invalid or corrupted input).
  Future<Uint8List?> decompress(Uint8List data) =>
      instance.decompress(data);
}
