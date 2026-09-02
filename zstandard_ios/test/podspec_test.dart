import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS podspec does not delete synced sources during a build', () {
    final podspec = File('ios/zstandard_ios.podspec').readAsStringSync();

    expect(podspec, contains('s.script_phases = ['));
    expect(podspec, contains(":name => 'Sync zstd'"));
    expect(podspec, contains(r'$(PODS_TARGET_SRCROOT)/Classes/zstd/zstd.h'));
    expect(podspec, isNot(contains('Remove synced zstd')));
    expect(podspec, isNot(contains('rm -rf')));
  });
}
