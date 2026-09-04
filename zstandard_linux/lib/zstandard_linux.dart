import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:zstandard_platform_interface/zstandard_platform_interface.dart';

import 'package:zstandard_native/zstandard_native_bindings.dart';

export 'zstandard_ext.dart';

const String _libName = 'zstandard_linux_plugin';

final DynamicLibrary _dylib = () {
  if (Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
}();

final ZstandardNativeBindings _bindings = ZstandardNativeBindings(_dylib);

bool _hasZstdFrameMagic(Uint8List data) {
  if (data.lengthInBytes < 4) {
    return false;
  }

  final int magic =
      data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
  return magic == ZSTD_MAGICNUMBER ||
      (magic & ZSTD_MAGIC_SKIPPABLE_MASK) == ZSTD_MAGIC_SKIPPABLE_START;
}

bool _isUnavailableContentSize(int size) {
  // The generated bindings expose these C unsigned values as -1 and -2.
  // Keep the unsigned representations as a compatibility guard for older
  // generated bindings and runtimes that returned the raw 64-bit bit pattern.
  return size == ZSTD_CONTENTSIZE_UNKNOWN ||
      size == ZSTD_CONTENTSIZE_ERROR ||
      size == 0xffffffffffffffff ||
      size == 0xfffffffffffffffe;
}

/// Linux implementation of [ZstandardPlatform] using FFI and the native zstd library.
///
/// Uses [DynamicLibrary] to load libzstandard_linux_plugin.so and calls
/// ZSTD_compress, ZSTD_decompress, ZSTD_compressBound, and ZSTD_getFrameContentSize.
/// The main [zstandard] plugin registers this implementation automatically on Linux.
class ZstandardLinux extends ZstandardPlatform {
  /// Creates the Linux platform implementation.
  ZstandardLinux();

  final methodChannel = const MethodChannel('plugins.flutter.io/zstandard');

  /// Registers this class as the default instance of [ZstandardPlatform].
  ///
  /// Called by the main plugin when running on Linux.
  static void registerWith() {
    ZstandardPlatform.instance = ZstandardLinux();
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) async {
    if (compressionLevel < 1 || compressionLevel > 22) {
      return null;
    }

    final int srcSize = data.lengthInBytes;
    final Pointer<Uint8> src =
        malloc.allocate<Uint8>(srcSize > 0 ? srcSize : 1);
    src.asTypedList(srcSize).setAll(0, data);

    final int dstCapacity = _bindings.ZSTD_compressBound(srcSize);
    if (_bindings.ZSTD_isError(dstCapacity) != 0 || dstCapacity <= 0) {
      malloc.free(src);
      return null;
    }
    final Pointer<Uint8> dst = malloc.allocate<Uint8>(dstCapacity);

    try {
      final int compressedSize = _bindings.ZSTD_compress(
        dst.cast(),
        dstCapacity,
        src.cast(),
        srcSize,
        compressionLevel,
      );

      if (_bindings.ZSTD_isError(compressedSize) == 0 && compressedSize > 0) {
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
    // Avoid entering the native decoder for arbitrary input. Apart from
    // being cheaper, this prevents malformed data from reaching an ABI
    // boundary while the frame header is already known to be invalid.
    if (!_hasZstdFrameMagic(data)) {
      return null;
    }

    final int compressedSize = data.lengthInBytes;
    final Pointer<Uint8> src = malloc.allocate<Uint8>(compressedSize);
    src.asTypedList(compressedSize).setAll(0, data);

    final int decompressedSizeExpected =
        _bindings.ZSTD_getFrameContentSize(src.cast(), compressedSize);
    if (_isUnavailableContentSize(decompressedSizeExpected)) {
      malloc.free(src);
      return null;
    }
    final int dstCapacity =
        decompressedSizeExpected > 0 ? decompressedSizeExpected : 1;
    final Pointer<Uint8> dst = malloc.allocate<Uint8>(dstCapacity);

    try {
      final int decompressedSize = _bindings.ZSTD_decompress(
        dst.cast(),
        dstCapacity,
        src.cast(),
        compressedSize,
      );

      if (_bindings.ZSTD_isError(decompressedSize) != 0) {
        return null;
      }
      return Uint8List.fromList(dst.asTypedList(decompressedSize));
    } finally {
      malloc.free(src);
      malloc.free(dst);
    }
  }
}

int compress(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int srcSize,
  int compressionLevel,
) =>
    _bindings.ZSTD_compress(
      dst,
      dstCapacity,
      src,
      srcSize,
      compressionLevel,
    );

int decompress(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int compressedSize,
) =>
    _bindings.ZSTD_decompress(
      dst,
      dstCapacity,
      src,
      compressedSize,
    );

Future<int> compressAsync(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int srcSize,
  int compressionLevel,
) async {
  final SendPort helperIsolateSendPort = await _getHelperIsolateSendPort();
  final int requestId = _nextCompressRequestId++;
  final _CompressRequest request = _CompressRequest(
      requestId, dst, dstCapacity, src, srcSize, compressionLevel);
  final Completer<int> completer = Completer<int>();
  _compressRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

Future<int> decompressAsync(
  Pointer<Void> dst,
  int dstCapacity,
  Pointer<Void> src,
  int compressedSize,
) async {
  final SendPort helperIsolateSendPort = await _getHelperIsolateSendPort();
  final int requestId = _nextDecompressRequestId++;
  final _DecompressRequest request =
      _DecompressRequest(requestId, dst, dstCapacity, src, compressedSize);
  final Completer<int> completer = Completer<int>();
  _decompressRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

// ==== Communication between isolates for asynchronous compression and decompression ==== //

/// Application for compression.
class _CompressRequest {
  final int id;
  final Pointer<Void> dst;
  final int dstCapacity;
  final Pointer<Void> src;
  final int srcSize;
  final int compressionLevel;

  const _CompressRequest(this.id, this.dst, this.dstCapacity, this.src,
      this.srcSize, this.compressionLevel);
}

/// Response with the compression result.
class _CompressResponse {
  final int id;
  final int result;

  const _CompressResponse(this.id, this.result);
}

/// Request for decompression.
class _DecompressRequest {
  final int id;
  final Pointer<Void> dst;
  final int dstCapacity;
  final Pointer<Void> src;
  final int compressedSize;

  const _DecompressRequest(
      this.id, this.dst, this.dstCapacity, this.src, this.compressedSize);
}

/// Response with the result of the decompression.
class _DecompressResponse {
  final int id;
  final int result;

  const _DecompressResponse(this.id, this.result);
}

/// Counters to identify compression and decompression requests.
int _nextCompressRequestId = 0;
int _nextDecompressRequestId = 0;

/// Mapping of requests to completers for compression and decompression.
final Map<int, Completer<int>> _compressRequests = <int, Completer<int>>{};
final Map<int, Completer<int>> _decompressRequests = <int, Completer<int>>{};

/// Port for sending requests to the auxiliary isolate.
// Start the worker lazily so importing the plugin cannot keep test processes
// alive when the async helper API is not used.
Future<SendPort>? _helperIsolateSendPort;

Future<SendPort> _getHelperIsolateSendPort() =>
    _helperIsolateSendPort ??= () async {
      final Completer<SendPort> completer = Completer<SendPort>();
      final ReceivePort receivePort = ReceivePort()
        ..listen((dynamic data) {
          if (data is SendPort) {
            completer.complete(data);
            return;
          }
          if (data is _CompressResponse) {
            final Completer<int> completer = _compressRequests[data.id]!;
            _compressRequests.remove(data.id);
            completer.complete(data.result);
            return;
          }
          if (data is _DecompressResponse) {
            final Completer<int> completer = _decompressRequests[data.id]!;
            _decompressRequests.remove(data.id);
            completer.complete(data.result);
            return;
          }
          throw UnsupportedError(
              'Message type not supported: ${data.runtimeType}');
        });

      await Isolate.spawn((SendPort sendPort) async {
        final ReceivePort helperReceivePort = ReceivePort()
          ..listen((dynamic data) {
            if (data is _CompressRequest) {
              final int result = _bindings.ZSTD_compress(
                  data.dst,
                  data.dstCapacity,
                  data.src,
                  data.srcSize,
                  data.compressionLevel);
              final _CompressResponse response =
                  _CompressResponse(data.id, result);
              sendPort.send(response);
              return;
            }
            if (data is _DecompressRequest) {
              final int result = _bindings.ZSTD_decompress(
                  data.dst, data.dstCapacity, data.src, data.compressedSize);
              final _DecompressResponse response =
                  _DecompressResponse(data.id, result);
              sendPort.send(response);
              return;
            }
            throw UnsupportedError(
                'Message type not supported: ${data.runtimeType}');
          });

        sendPort.send(helperReceivePort.sendPort);
      }, receivePort.sendPort);

      return completer.future;
    }();
