import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS podspec generates zstd sources from the native package', () {
    final podspec = File('ios/zstandard_ios.podspec').readAsStringSync();

    expect(podspec, contains("'Classes/zstd/**/*.c'"));
    expect(podspec, contains("'zstandard_ios/Sources/zstandard_ios/*.swift'"));
    expect(
      podspec,
      contains("'Classes/zstd/zstd.h', 'Classes/zstd/zstd_errors.h'"),
    );
    expect(podspec, contains('s.prepare_command'));
    expect(podspec, contains('s.script_phases = ['));
    expect(podspec, contains('sync_zstd.sh'));
    expect(podspec, isNot(contains('Sources/zstd/**/*.c')));
    expect(podspec, isNot(contains('rm -rf')));
  });
}
