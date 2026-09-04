import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('package metadata meets pub.dev publication requirements', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final descriptionLine = pubspec
        .split('\n')
        .firstWhere((line) => line.startsWith('description:'));
    final description = descriptionLine
        .substring('description:'.length)
        .trim()
        .replaceAll('"', '')
        .replaceAll("'", '');

    expect(description.length, inInclusiveRange(50, 180));
    expect(pubspec, contains('homepage: https://'));
    expect(pubspec, contains('repository: https://'));

    for (final file in ['README.md', 'CHANGELOG.md', 'LICENSE']) {
      expect(
        File(file).existsSync(),
        isTrue,
        reason: '$file must be published',
      );
    }

    for (final platform in [
      'android',
      'ios',
      'linux',
      'macos',
      'web',
      'windows',
    ]) {
      expect(pubspec, contains('      $platform:'));
    }
  });
}
