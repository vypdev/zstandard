import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zstandard_windows/zstandard_windows.dart';

void main() {
  test('ZstandardWindows can be instantiated on Windows', () {
    if (!Platform.isWindows) return;
    expect(ZstandardWindows(), isA<ZstandardWindows>());
  }, skip: !Platform.isWindows ? 'Only runs on Windows' : false);
}
