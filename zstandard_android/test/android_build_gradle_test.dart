import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android plugin uses Built-in Kotlin without applying KGP', () {
    final buildGradle = File('android/build.gradle').readAsStringSync();

    expect(buildGradle,
        contains('classpath("com.android.tools.build:gradle:9.1.0")'));
    expect(buildGradle, isNot(contains('kotlin-android')));
    expect(buildGradle, isNot(contains('kotlin-gradle-plugin')));
    expect(buildGradle, isNot(contains('android.kotlinOptions')));
    expect(buildGradle, isNot(contains('main.java.srcDirs +=')));
  });
}
