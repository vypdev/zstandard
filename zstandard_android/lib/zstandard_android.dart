import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:zstandard_platform_interface/zstandard_platform_interface.dart';

import 'package:zstandard_native/zstandard_native.dart'
    show ZstandardNativeCodec;
import 'package:zstandard_native/zstandard_native_bindings.dart';

export 'zstandard_ext.dart';

const String _libName = 'zstandard_android';

final DynamicLibrary _dylib = () {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
}();

final ZstandardNativeBindings _bindings = ZstandardNativeBindings(_dylib);
final ZstandardNativeCodec _codec = ZstandardNativeCodec(_bindings);

bool _hasZstdFrameMagic(Uint8List data) {
  if (data.lengthInBytes < 4) {
    return false;
  }

  final int magic =
      data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
  return magic == ZSTD_MAGICNUMBER ||
      (magic & ZSTD_MAGIC_SKIPPABLE_MASK) == ZSTD_MAGIC_SKIPPABLE_START;
}

/// Android implementation of [ZstandardPlatform] using FFI and the native zstd library.
///
/// Loads libzstandard_android.so and uses the shared byte-oriented codec. The
/// main [zstandard] plugin registers this implementation automatically.
class ZstandardAndroid extends ZstandardPlatform
    implements BoundedZstandardPlatform {
  /// Creates the Android platform implementation.
  ZstandardAndroid();

  final methodChannel = const MethodChannel('plugins.flutter.io/zstandard');

  /// Registers this class as the default instance of [ZstandardPlatform].
  ///
  /// Called by the main plugin when running on Android.
  static void registerWith() {
    ZstandardPlatform.instance = ZstandardAndroid();
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) =>
      Isolate.run(() => _codec.compress(data, compressionLevel));

  @override
  Future<Uint8List?> decompress(Uint8List data) => decompressWithOptions(data);

  @override
  Future<Uint8List?> decompressWithOptions(
    Uint8List data, {
    int maxOutputSize = ZstandardPlatform.defaultMaxDecompressedSize,
  }) => Isolate.run(
    () => _hasZstdFrameMagic(data)
        ? _codec.decompress(data, maxOutputSize: maxOutputSize)
        : null,
  );
}

int compress(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int srcSize,
  int compressionLevel,
) => _bindings.ZSTD_compress(dst, dstCapacity, src, srcSize, compressionLevel);

int decompress(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int compressedSize,
) => _bindings.ZSTD_decompress(dst, dstCapacity, src, compressedSize);

@Deprecated('Use ZstandardAndroid.compress with Dart-owned bytes instead.')
Future<int> compressAsync(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int srcSize,
  int compressionLevel,
) => Future<int>.sync(
  () => compress(dst, dstCapacity, src, srcSize, compressionLevel),
);

@Deprecated('Use ZstandardAndroid.decompress with Dart-owned bytes instead.')
Future<int> decompressAsync(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int compressedSize,
) => Future<int>.sync(() => decompress(dst, dstCapacity, src, compressedSize));
