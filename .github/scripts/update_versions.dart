// ignore_for_file: avoid_print
/// Updates version and dependency versions across federated plugin pubspec files.
/// Usage: dart run .github/scripts/update_versions.dart <new_version> [--release]
/// Example: dart run .github/scripts/update_versions.dart 1.3.30 --release
///
/// The optional --release flag also pins the Apple SwiftPM manifests and
/// updates the CocoaPods podspec versions. Development checkouts may keep
/// using the develop branch; published archives must contain an immutable
/// dependency declaration.

import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty ||
      args.length > 2 ||
      (args.length == 2 && args[1] != '--release')) {
    print(
      'Usage: dart run .github/scripts/update_versions.dart <new_version> [--release]',
    );
    exit(1);
  }
  final version = args.first.trim();
  final release = args.length == 2;
  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
    print('Error: version must be semver (e.g. 1.0.0), got: $version');
    exit(1);
  }

  final repoRoot = _findRepoRoot();
  final packages = _packageConfig(repoRoot);

  for (final entry in packages.entries) {
    final path = '${repoRoot}/${entry.key}/pubspec.yaml';
    final file = File(path);
    if (!file.existsSync()) {
      print('Error: $path not found');
      exit(1);
    }
    var content = file.readAsStringSync();
    content = _updateVersionInContent(content, entry.value, version);
    file.writeAsStringSync(content);
    print('Updated $path');
  }

  if (release) {
    _updateReleaseMetadata(repoRoot, version);
  }

  print('Verifying...');
  for (final entry in packages.entries) {
    final path = '${repoRoot}/${entry.key}/pubspec.yaml';
    final content = File(path).readAsStringSync();
    if (!content.contains('version: $version')) {
      print('Error: $path does not contain version: $version after update');
      exit(1);
    }
    for (final dep in entry.value.deps) {
      if (!content.contains('$dep: ^$version') &&
          !content.contains('$dep: $version')) {
        print('Error: $path missing dependency $dep: ^$version');
        exit(1);
      }
    }
  }

  if (release) {
    _verifyReleaseMetadata(repoRoot, version);
  }
  print('All versions updated and verified.');
}

void _updateReleaseMetadata(String root, String version) {
  final manifests = [
    '$root/zstandard_ios/ios/zstandard_ios/Package.swift',
    '$root/zstandard_macos/macos/zstandard_macos/Package.swift',
  ];
  for (final path in manifests) {
    final file = File(path);
    if (!file.existsSync()) {
      print('Error: SwiftPM manifest not found: $path');
      exit(1);
    }
    var content = file.readAsStringSync();
    content = content.replaceFirstMapped(
      RegExp(r'branch:\s*"develop"'),
      (_) => 'exact: "$version"',
    );
    file.writeAsStringSync(content);
    print('Pinned $path to $version');
  }

  final podspecs = [
    '$root/zstandard_ios/ios/zstandard_ios.podspec',
    '$root/zstandard_macos/macos/zstandard_macos.podspec',
  ];
  for (final path in podspecs) {
    final file = File(path);
    if (!file.existsSync()) {
      print('Error: CocoaPods podspec not found: $path');
      exit(1);
    }
    var content = file.readAsStringSync();
    content = content.replaceFirstMapped(
      RegExp(r"(s\.version\s*=\s*')[^']+(')"),
      (match) => '${match[1]}$version${match[2]}',
    );
    file.writeAsStringSync(content);
    print('Updated $path to $version');
  }
}

void _verifyReleaseMetadata(String root, String version) {
  final manifests = [
    '$root/zstandard_ios/ios/zstandard_ios/Package.swift',
    '$root/zstandard_macos/macos/zstandard_macos/Package.swift',
  ];
  for (final path in manifests) {
    final content = File(path).readAsStringSync();
    if (!content.contains('exact: "$version"') ||
        content.contains('branch: "develop"')) {
      print('Error: $path is not pinned to exact release $version');
      exit(1);
    }
  }

  final podspecs = [
    '$root/zstandard_ios/ios/zstandard_ios.podspec',
    '$root/zstandard_macos/macos/zstandard_macos.podspec',
  ];
  for (final path in podspecs) {
    final content = File(path).readAsStringSync();
    if (!RegExp("s\\.version\\s*=\\s*'$version'").hasMatch(content)) {
      print('Error: $path does not contain version $version');
      exit(1);
    }
  }
}

String _findRepoRoot() {
  var dir = Directory.current.path;
  while (dir != '/' && dir.isNotEmpty) {
    if (File('$dir/pubspec.yaml').existsSync() ||
        File('$dir/zstandard/pubspec.yaml').existsSync()) {
      if (File('$dir/zstandard/pubspec.yaml').existsSync()) return dir;
    }
    dir = Directory(dir).parent.path;
  }
  return Directory.current.path;
}

String _updateVersionInContent(
  String content,
  PackageSpec spec,
  String version,
) {
  content = content.replaceFirst(
    RegExp(r'^version:\s*[\d.]+\s*$', multiLine: true),
    'version: $version\n',
  );
  for (final dep in spec.deps) {
    content = content.replaceFirstMapped(
      RegExp(r'(\s*' + dep + r':\s*)\^?[\d.]+'),
      (m) => '${m[1]}^$version',
    );
  }
  return content;
}

class PackageSpec {
  const PackageSpec({required this.deps});
  final List<String> deps;
}

Map<String, PackageSpec> _packageConfig(String root) {
  return {
    'zstandard_platform_interface': const PackageSpec(deps: []),
    'zstandard_native': const PackageSpec(deps: []),
    'zstandard_android': const PackageSpec(
      deps: ['zstandard_platform_interface', 'zstandard_native'],
    ),
    'zstandard_ios': const PackageSpec(
      deps: ['zstandard_platform_interface', 'zstandard_native'],
    ),
    'zstandard_macos': const PackageSpec(
      deps: ['zstandard_platform_interface', 'zstandard_native'],
    ),
    'zstandard_linux': const PackageSpec(
      deps: ['zstandard_platform_interface', 'zstandard_native'],
    ),
    'zstandard_windows': const PackageSpec(
      deps: ['zstandard_platform_interface', 'zstandard_native'],
    ),
    'zstandard_web': const PackageSpec(deps: ['zstandard_platform_interface']),
    'zstandard_cli': const PackageSpec(deps: ['zstandard_native']),
    'zstandard': const PackageSpec(
      deps: [
        'zstandard_platform_interface',
        'zstandard_android',
        'zstandard_ios',
        'zstandard_linux',
        'zstandard_macos',
        'zstandard_web',
        'zstandard_windows',
      ],
    ),
  };
}
