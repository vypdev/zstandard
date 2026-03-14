import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:platform/platform.dart';

import 'utils/lib_loader.dart';
import 'zstandard_cli_bindings_generated.dart';
import 'zstandard_interface.dart';

class ZstandardCLI implements ZstandardInterface {
  final ZstandardCLIBindings _bindings =
      ZstandardCLIBindings(openZstdLibrary());

  @override
  @override
  Future<Uint8List?> compress(
    Uint8List data, {
    int compressionLevel = 3,
  }) async {
    if (data.isEmpty) return data;
    final int srcSize = data.lengthInBytes;
    final Pointer<Uint8> src = malloc.allocate<Uint8>(srcSize);
    src.asTypedList(srcSize).setAll(0, data);

    final int dstCapacity = _bindings.ZSTD_compressBound(srcSize);
    final Pointer<Uint8> dst = malloc.allocate<Uint8>(dstCapacity);

    try {
      final int compressedSize = _bindings.ZSTD_compress(
        dst.cast(),
        dstCapacity,
        src.cast(),
        srcSize,
        compressionLevel,
      );

      if (compressedSize > 0) {
        return Uint8List.fromList(dst.asTypedList(compressedSize));
      } else {
        return null;
      }
    } finally {
      malloc.free(src);
      malloc.free(dst);
    }
  }

  @override
  Future<Uint8List?> decompress(Uint8List data) async {
    if (data.isEmpty) return data;
    const int contentSizeUnknown = -1;
    const int contentSizeError = -2;

    final int compressedSize = data.lengthInBytes;
    final Pointer<Uint8> src = malloc.allocate<Uint8>(compressedSize);
    src.asTypedList(compressedSize).setAll(0, data);

    final int decompressedSizeExpected =
        _bindings.ZSTD_getFrameContentSize(src.cast(), compressedSize);
    final int dstCapacity =
        (decompressedSizeExpected != contentSizeUnknown &&
                decompressedSizeExpected != contentSizeError &&
                decompressedSizeExpected > 0)
            ? decompressedSizeExpected
            : compressedSize * 20;
    final Pointer<Uint8> dst = malloc.allocate<Uint8>(dstCapacity);

    try {
      final int decompressedSize = _bindings.ZSTD_decompress(
        dst.cast(),
        dstCapacity,
        src.cast(),
        compressedSize,
      );

      if (decompressedSize > 0) {
        return Uint8List.fromList(dst.asTypedList(decompressedSize));
      } else {
        return null;
      }
    } finally {
      malloc.free(src);
      malloc.free(dst);
    }
  }

  @override
  Future<String?> getPlatformVersion() {
    final platform = LocalPlatform();

    String version;
    if (platform.isMacOS) {
      version = 'macOS ${platform.version}';
    } else if (platform.isWindows) {
      version = 'Windows ${platform.version}';
    } else if (platform.isLinux) {
      version = 'Linux ${platform.version}';
    } else {
      version = 'Unknown platform';
    }

    return Future.value(version);
  }
}
