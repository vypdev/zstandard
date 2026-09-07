import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../zstandard_native_bindings.dart';

/// Default maximum number of bytes produced by one decompression operation.
const int nativeDefaultMaxDecompressedSize = 256 * 1024 * 1024;

/// Memory-safe, bounded convenience wrapper around the generated zstd bindings.
///
/// Instances do not retain native state and may be recreated in worker isolates.
final class ZstandardNativeCodec {
  /// Creates a codec backed by [bindings].
  const ZstandardNativeCodec(this.bindings);

  /// The generated zstd bindings used by this codec.
  final ZstandardNativeBindings bindings;

  /// Compresses [data] into one valid zstd frame.
  Uint8List? compress(Uint8List data, int compressionLevel) {
    if (compressionLevel < 1 || compressionLevel > 22) {
      return null;
    }

    Pointer<Uint8>? src;
    Pointer<Uint8>? dst;
    try {
      final srcSize = data.lengthInBytes;
      src = malloc.allocate<Uint8>(srcSize == 0 ? 1 : srcSize);
      if (srcSize > 0) {
        src.asTypedList(srcSize).setAll(0, data);
      }

      final dstCapacity = bindings.ZSTD_compressBound(srcSize);
      if (bindings.ZSTD_isError(dstCapacity) != 0 || dstCapacity <= 0) {
        return null;
      }
      dst = malloc.allocate<Uint8>(dstCapacity);

      final compressedSize = bindings.ZSTD_compress(
        dst.cast(),
        dstCapacity,
        src.cast(),
        srcSize,
        compressionLevel,
      );
      if (bindings.ZSTD_isError(compressedSize) != 0 || compressedSize <= 0) {
        return null;
      }
      return Uint8List.fromList(dst.asTypedList(compressedSize));
    } on ArgumentError {
      // package:ffi reports a failed native allocation as ArgumentError.
      return null;
    } finally {
      if (src != null) malloc.free(src);
      if (dst != null) malloc.free(dst);
    }
  }

  /// Decompresses complete zstd/skippable frames without trusting frame sizes.
  ///
  /// Streaming decompression supports frames that omit their content size. The
  /// operation fails before returning more than [maxOutputSize] bytes.
  Uint8List? decompress(
    Uint8List data, {
    int maxOutputSize = nativeDefaultMaxDecompressedSize,
  }) {
    if (data.isEmpty || maxOutputSize < 0) {
      return null;
    }

    final stream = bindings.ZSTD_createDStream();
    if (stream == nullptr) {
      return null;
    }

    Pointer<Uint8>? src;
    Pointer<ZSTD_inBuffer>? input;
    Pointer<ZSTD_outBuffer>? output;
    Pointer<Uint8>? chunk;
    final result = BytesBuilder(copy: false);

    try {
      src = malloc.allocate<Uint8>(data.lengthInBytes);
      input = calloc<ZSTD_inBuffer>();
      output = calloc<ZSTD_outBuffer>();
      final recommendedOutputSize = bindings.ZSTD_DStreamOutSize();
      final chunkCapacity =
          recommendedOutputSize > 0 ? recommendedOutputSize : 128 * 1024;
      chunk = malloc.allocate<Uint8>(chunkCapacity);

      src.asTypedList(data.lengthInBytes).setAll(0, data);
      input.ref
        ..src = src.cast()
        ..size = data.lengthInBytes
        ..pos = 0;
      output.ref
        ..dst = chunk.cast()
        ..size = chunkCapacity
        ..pos = 0;

      final initialization = bindings.ZSTD_initDStream(stream);
      if (bindings.ZSTD_isError(initialization) != 0) {
        return null;
      }

      var previousInputPosition = -1;
      var previousOutputLength = -1;
      while (true) {
        output.ref
          ..dst = chunk.cast()
          ..size = chunkCapacity
          ..pos = 0;

        final remaining = bindings.ZSTD_decompressStream(stream, output, input);
        if (bindings.ZSTD_isError(remaining) != 0) {
          return null;
        }

        final produced = output.ref.pos;
        if (result.length + produced > maxOutputSize) {
          return null;
        }
        if (produced > 0) {
          result.add(Uint8List.fromList(chunk.asTypedList(produced)));
        }

        final allInputConsumed = input.ref.pos == input.ref.size;
        if (remaining == 0 && allInputConsumed) {
          return result.takeBytes();
        }

        final madeProgress = input.ref.pos != previousInputPosition ||
            result.length != previousOutputLength;
        if (!madeProgress || (allInputConsumed && produced == 0)) {
          // More input is required: the frame is truncated or incomplete.
          return null;
        }
        previousInputPosition = input.ref.pos;
        previousOutputLength = result.length;
      }
    } on ArgumentError {
      return null;
    } finally {
      bindings.ZSTD_freeDStream(stream);
      if (src != null) malloc.free(src);
      if (input != null) calloc.free(input);
      if (output != null) calloc.free(output);
      if (chunk != null) malloc.free(chunk);
    }
  }
}
