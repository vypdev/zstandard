import 'dart:io';

const packageNames = [
  'zstandard',
  'zstandard_android',
  'zstandard_cli',
  'zstandard_ios',
  'zstandard_linux',
  'zstandard_macos',
  'zstandard_native',
  'zstandard_platform_interface',
  'zstandard_web',
  'zstandard_windows',
];

String? descriptionFrom(String contents) {
  for (final line in contents.split('\n')) {
    if (line.startsWith('description:')) {
      return line
          .substring('description:'.length)
          .trim()
          .replaceAll('"', '')
          .replaceAll("'", '');
    }
  }
  return null;
}

void main(List<String> args) {
  String? releaseVersion;
  if (args.isNotEmpty) {
    if (args.length != 2 || args[0] != '--release-version') {
      stderr.writeln(
        'Usage: dart scripts/check_pub_metadata.dart [--release-version X.Y.Z]',
      );
      exitCode = 2;
      return;
    }
    releaseVersion = args[1];
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(releaseVersion)) {
      stderr.writeln('Invalid release version: $releaseVersion');
      exitCode = 2;
      return;
    }
  }
  final errors = <String>[];

  for (final package in packageNames) {
    final packageDir = Directory(package);
    final pubspec = File('$package/pubspec.yaml');
    if (!pubspec.existsSync()) {
      errors.add('$package is missing pubspec.yaml');
      continue;
    }

    final contents = pubspec.readAsStringSync();
    if (releaseVersion != null &&
        !RegExp(
          r'^version:\s*' + RegExp.escape(releaseVersion) + r'\s*$',
          multiLine: true,
        ).hasMatch(contents)) {
      errors.add('$package version is not $releaseVersion');
    }
    final description = descriptionFrom(contents);
    if (description == null ||
        description.length < 50 ||
        description.length > 180) {
      errors.add('$package description must contain 50-180 characters');
    }
    if (!contents.contains('homepage: https://')) {
      errors.add('$package homepage must use HTTPS');
    }
    if (!contents.contains('repository: https://')) {
      errors.add('$package repository must use HTTPS');
    }

    for (final file in ['README.md', 'CHANGELOG.md', 'LICENSE']) {
      if (!File('$package/$file').existsSync()) {
        errors.add('$package is missing $file');
      }
    }

    if (!packageDir.existsSync()) {
      errors.add('$package directory does not exist');
    }
  }

  final mainPubspec = File('zstandard/pubspec.yaml').readAsStringSync();
  for (final platform in [
    'android',
    'ios',
    'linux',
    'macos',
    'web',
    'windows',
  ]) {
    if (!mainPubspec.contains('      $platform:')) {
      errors.add('zstandard does not declare the $platform Flutter platform');
    }
  }

  for (final manifest in [
    'zstandard_ios/ios/zstandard_ios/Package.swift',
    'zstandard_macos/macos/zstandard_macos/Package.swift',
  ]) {
    if (!File(manifest).existsSync()) {
      errors.add('Missing Swift Package Manager manifest: $manifest');
    } else {
      final contents = File(manifest).readAsStringSync();
      if (!contents.contains('product(name: "zstandard-native"')) {
        errors.add(
          '$manifest does not consume the shared zstandard-native product',
        );
      }
      if (releaseVersion != null &&
          (!contents.contains('exact: "$releaseVersion"') ||
              contents.contains('branch: "develop"'))) {
        errors.add('$manifest must pin the native package to $releaseVersion');
      }
    }
  }

  for (final podspec in [
    'zstandard_ios/ios/zstandard_ios.podspec',
    'zstandard_macos/macos/zstandard_macos.podspec',
  ]) {
    if (!File(podspec).existsSync()) {
      errors.add('Missing CocoaPods podspec: $podspec');
    } else if (releaseVersion != null &&
        !RegExp("s\\.version\\s*=\\s*'$releaseVersion'")
            .hasMatch(File(podspec).readAsStringSync())) {
      errors.add('$podspec must contain version $releaseVersion');
    }
  }

  if (!File('zstandard_native/src/zstd/zstd.h').existsSync()) {
    errors.add(
      'Canonical zstd source is missing zstandard_native/src/zstd/zstd.h',
    );
  }
  for (final duplicate in [
    'zstandard_ios/ios/zstandard_ios/Sources/zstd',
    'zstandard_macos/macos/zstandard_macos/Sources/zstd',
  ]) {
    if (Directory(duplicate).existsSync()) {
      errors.add(
        'Duplicated SwiftPM zstd source directory must not exist: $duplicate',
      );
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln('Publication metadata check failed:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Publication metadata is valid for ${packageNames.length} packages.',
  );
}
