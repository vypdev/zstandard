import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android plugin leaves Kotlin configuration to the consuming app', () {
    final buildGradle = File('android/build.gradle').readAsStringSync();

    // The application owns the AGP version. Pinning it from this library
    // would make it impossible to consume the plugin from legacy projects.
    expect(buildGradle, isNot(contains('com.android.tools.build:gradle:')));
    expect(buildGradle, contains('apply plugin: "com.android.library"'));
    expect(buildGradle, isNot(contains('kotlin-android')));
    expect(buildGradle, isNot(contains('kotlin-gradle-plugin')));
    expect(buildGradle, isNot(contains('android.kotlinOptions')));
    expect(buildGradle, isNot(contains('KotlinCompile')));
    expect(buildGradle, isNot(contains('compilerOptions')));
  });

  test('CI examples cover AGP 9 and the supported legacy AGP line', () {
    final modernSettings = File(
      'example/android/settings.gradle',
    ).readAsStringSync();
    final legacySettings = File(
      'example_legacy/android/settings.gradle',
    ).readAsStringSync();

    expect(modernSettings, contains('version "9.1.0"'));
    expect(legacySettings, contains('version "8.11.1"'));
    expect(legacySettings, contains('version "2.2.20"'));

    final legacyGradleProperties = File(
      'example_legacy/android/gradle.properties',
    ).readAsStringSync();
    expect(legacyGradleProperties, contains('android.builtInKotlin=false'));
  });
}
