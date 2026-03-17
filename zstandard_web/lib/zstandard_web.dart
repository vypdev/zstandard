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
/// Calls the global `compressData` and `decompressData` functions provided by
/// zstd.js / zstd.wasm. Requires zstd.js and zstd.wasm to be loaded in the
/// page (e.g. via a script tag in index.html). The main [zstandard] plugin
/// registers this implementation automatically on web.
class ZstandardWeb extends ZstandardPlatform {
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
    var promise = html.window.callMethodVarArgs('compressData'.toJS, [
      data.toJS,
      compressionLevel.toJS,
    ]) as JSPromise;
    var compressedData = (await promise.toDart) as JSUint8Array?;
    if (compressedData != null) {
      return compressedData.toDart;
    } else {
      throw Exception("Error compressing.");
    }
  }

  @override
  Future<Uint8List?> decompress(Uint8List data) async {
    var promise = html.window.callMethodVarArgs('decompressData'.toJS, [
      data.toJS,
    ]) as JSPromise;
    var decompressedData = (await promise.toDart) as JSUint8Array?;
    if (decompressedData != null) {
      return decompressedData.toDart;
    } else {
      throw Exception("Error decompressing.");
    }
  }
}
