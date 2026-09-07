import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_web_plugins/flutter_web_plugins.dart' show Registrar;
import 'package:web/web.dart' as html;
import 'package:zstandard_platform_interface/zstandard_platform_interface.dart';

export 'zstandard_ext.dart';

/// Web implementation of [ZstandardPlatform] using JavaScript and WebAssembly.
///
/// Calls the asynchronous `compressData` and `decompressData` broker functions
/// provided by `zstd.js`. The broker transfers work to `zstd_worker.js`, which
/// loads `zstd_core.js` and `zstd.wasm` away from the browser UI thread. All
/// four files must be deployed together. The main [zstandard] plugin registers
/// this implementation automatically on web.
class ZstandardWeb extends ZstandardPlatform
    implements BoundedZstandardPlatform {
  /// Creates the web platform implementation.
  ///
  /// [debugWindow] is visible for testing to override the window object.
  ZstandardWeb({@visibleForTesting html.Window? debugWindow});

  /// Registers this class as the default instance of [ZstandardPlatform].
  ///
  /// Called by the main plugin when running on web. [registrar] is the
  /// web plugin registrar.
  static void registerWith(Registrar registrar) {
    ZstandardPlatform.instance = ZstandardWeb();
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = html.window.navigator.userAgent;
    return version;
  }

  @override
  Future<Uint8List?> compress(Uint8List data, int compressionLevel) async {
    if (compressionLevel < 1 || compressionLevel > 22) return null;
    try {
      var promise = html.window.callMethodVarArgs('compressData'.toJS, [
        data.toJS,
        compressionLevel.toJS,
      ]) as JSPromise;
      var compressedData = (await promise.toDart) as JSUint8Array?;
      if (compressedData != null) {
        return compressedData.toDart;
      }
    } on Object {
      return null;
    }
    return null;
  }

  @override
  Future<Uint8List?> decompress(Uint8List data) => decompressWithOptions(data);

  @override
  Future<Uint8List?> decompressWithOptions(
    Uint8List data, {
    int maxOutputSize = ZstandardPlatform.defaultMaxDecompressedSize,
  }) async {
    if (maxOutputSize < 0) return null;
    try {
      var promise = html.window.callMethodVarArgs('decompressData'.toJS, [
        data.toJS,
        maxOutputSize.toJS,
      ]) as JSPromise;
      var decompressedData = (await promise.toDart) as JSUint8Array?;
      if (decompressedData != null) {
        return decompressedData.toDart;
      }
    } on Object {
      return null;
    }
    return null;
  }
}
