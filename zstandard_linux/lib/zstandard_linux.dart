import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:zstandard_native/zstandard_native.dart'
    show ZstandardNativeCodec;
import 'package:zstandard_native/zstandard_native_bindings.dart';
import 'package:zstandard_platform_interface/zstandard_platform_interface.dart';

export 'zstandard_ext.dart';

const String _libName = 'zstandard_linux_plugin';

final DynamicLibrary _dylib = () {
  if (Platform.isLinux) return DynamicLibrary.open('lib$_libName.so');
  throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
}();

final ZstandardNativeBindings _bindings = ZstandardNativeBindings(_dylib);
final ZstandardNativeCodec _codec = ZstandardNativeCodec(_bindings);

bool _hasZstdFrameMagic(Uint8List data) {
  if (data.lengthInBytes < 4) return false;
  final magic = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
  return magic == ZSTD_MAGICNUMBER ||
      (magic & ZSTD_MAGIC_SKIPPABLE_MASK) == ZSTD_MAGIC_SKIPPABLE_START;
}

/// Linux implementation of [ZstandardPlatform] using the native zstd library.
class ZstandardLinux extends ZstandardPlatform
    implements BoundedZstandardPlatform {
  /// Creates the Linux platform implementation.
  ZstandardLinux();

  final methodChannel = const MethodChannel('plugins.flutter.io/zstandard');

  /// Registers this implementation with the federated plugin.
  static void registerWith() {
    ZstandardPlatform.instance = ZstandardLinux();
  }

  @override
  Future<String?> getPlatformVersion() =>
      methodChannel.invokeMethod<String>('getPlatformVersion');

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

/// Low-level synchronous compression for existing FFI consumers.
int compress(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int srcSize,
  int compressionLevel,
) => _bindings.ZSTD_compress(dst, dstCapacity, src, srcSize, compressionLevel);

/// Low-level synchronous decompression for existing FFI consumers.
int decompress(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int compressedSize,
) => _bindings.ZSTD_decompress(dst, dstCapacity, src, compressedSize);

/// Compatibility wrapper that completes after the pointer call returns.
@Deprecated('Use ZstandardLinux.compress with Dart-owned bytes instead.')
Future<int> compressAsync(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int srcSize,
  int compressionLevel,
) => Future<int>.sync(
  () => compress(dst, dstCapacity, src, srcSize, compressionLevel),
);

/// Compatibility wrapper that completes after the pointer call returns.
@Deprecated('Use ZstandardLinux.decompress with Dart-owned bytes instead.')
Future<int> decompressAsync(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int compressedSize,
) => Future<int>.sync(() => decompress(dst, dstCapacity, src, compressedSize));
