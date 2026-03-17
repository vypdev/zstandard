import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zstandard_linux/zstandard_linux.dart';

void main() {
  test('ZstandardLinux can be instantiated on Linux', () {
    if (!Platform.isLinux) return;
    expect(ZstandardLinux(), isA<ZstandardLinux>());
  }, skip: !Platform.isLinux ? 'Only runs on Linux' : false);
}
