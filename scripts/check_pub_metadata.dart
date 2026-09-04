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

void main() {
  final errors = <String>[];

  for (final package in packageNames) {
    final packageDir = Directory(package);
    final pubspec = File('$package/pubspec.yaml');
    if (!pubspec.existsSync()) {
      errors.add('$package is missing pubspec.yaml');
      continue;
    }

    final contents = pubspec.readAsStringSync();
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
