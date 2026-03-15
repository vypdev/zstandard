import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zstandard_platform_interface_method_channel.dart';

/// Abstract platform interface for Zstandard compression and decompression.
///
/// All platform implementations (Android, iOS, macOS, Linux, Windows, web)
/// must extend this class and implement [getPlatformVersion], [compress],
/// and [decompress]. They register themselves by setting [instance].
///
/// Application code should use the main [zstandard] package, not this interface.
abstract class ZstandardPlatform extends PlatformInterface {
  /// Constructs a [ZstandardPlatform].
  ZstandardPlatform() : super(token: _token);

  static final Object _token = Object();

  static ZstandardPlatform _instance = MethodChannelZstandardPlatform();

  /// The default instance of [ZstandardPlatform] to use.
  ///
  /// Defaults to [MethodChannelZstandardPlatform]. Platform packages set this
  /// in their registerWith() (or equivalent) so the main plugin uses the
  /// native implementation.
  static ZstandardPlatform get instance => _instance;

  /// Sets the platform implementation.
  ///
  /// Only instances created with the correct token (from this package) can
  /// be set. Platform-specific implementations call this when they register.
  static set instance(ZstandardPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns a platform-specific version or identifier string.
  ///
  /// Default implementation throws [UnimplementedError].
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Compresses [data] at the given [compressionLevel] (1–22).
  ///
  /// Default implementation throws [UnimplementedError].
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) {
    throw UnimplementedError('compress() has not been implemented.');
  }

  /// Decompresses Zstandard-compressed [data].
  ///
  /// Default implementation throws [UnimplementedError].
  Future<Uint8List?> decompress(Uint8List data) {
    throw UnimplementedError('decompress() has not been implemented.');
  }
}
