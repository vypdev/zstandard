import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'zstandard_platform.dart';

/// An implementation of [ZstandardPlatform] that uses method channels.
class MethodChannelZstandardPlatform extends ZstandardPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('plugins.flutter.io/zstandard');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
