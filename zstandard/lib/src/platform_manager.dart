import 'dart:io';

import 'package:flutter/foundation.dart';

class PlatformManager {
  bool get isWeb => kIsWeb;

  bool get isMacOS {
    if (isWeb) {
      return false;
    }
    return Platform.isMacOS;
  }

  bool get isAndroid {
    if (isWeb) {
      return false;
    }
    return Platform.isAndroid;
  }

  bool get isIOS {
    if (isWeb) {
      return false;
    }
    return Platform.isIOS;
  }

  bool get isFuchsia {
    if (isWeb) {
      return false;
    }
    return Platform.isFuchsia;
  }

  bool get isWindows {
    if (isWeb) {
      return false;
    }
    return Platform.isWindows;
  }

  bool get isDesktop {
    return isWindows || isLinux || isMacOS;
  }

  bool get isLinux {
    if (isWeb) {
      return false;
    }
    return Platform.isLinux;
  }

  static PlatformManager? _instance;

  PlatformManager._internal();

  factory PlatformManager() {
    _instance ??= PlatformManager._internal();
    return _instance!;
  }
}
