// ignore_for_file: avoid_print
/// Updates version and dependency versions across federated plugin pubspec files.
/// Usage: dart run .github/scripts/update_versions.dart <new_version>
/// Example: dart run .github/scripts/update_versions.dart 1.3.30

import 'dart:io';

void main(List<String> args) {
  if (args.length != 1) {
    print('Usage: dart run .github/scripts/update_versions.dart <new_version>');
    exit(1);
  }
  final version = args.single.trim();
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

  print('Verifying...');
  for (final entry in packages.entries) {
    final path = '${repoRoot}/${entry.key}/pubspec.yaml';
    final content = File(path).readAsStringSync();
    if (!content.contains('version: $version')) {
      print('Error: $path does not contain version: $version after update');
      exit(1);
    }
    for (final dep in entry.value.deps) {
      if (!content.contains('$dep: ^$version') && !content.contains('$dep: $version')) {
        print('Error: $path missing dependency $dep: ^$version');
        exit(1);
      }
    }
  }
  print('All versions updated and verified.');
}

String _findRepoRoot() {
  var dir = Directory.current.path;
  while (dir != '/' && dir.isNotEmpty) {
    if (File('$dir/pubspec.yaml').existsSync() || File('$dir/zstandard/pubspec.yaml').existsSync()) {
      if (File('$dir/zstandard/pubspec.yaml').existsSync()) return dir;
    }
    dir = Directory(dir).parent.path;
  }
  return Directory.current.path;
}

String _updateVersionInContent(String content, PackageSpec spec, String version) {
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
    'zstandard_android': const PackageSpec(deps: ['zstandard_platform_interface']),
    'zstandard_ios': const PackageSpec(deps: ['zstandard_platform_interface']),
    'zstandard_macos': const PackageSpec(deps: ['zstandard_platform_interface']),
    'zstandard_linux': const PackageSpec(deps: ['zstandard_platform_interface']),
    'zstandard_windows': const PackageSpec(deps: ['zstandard_platform_interface']),
    'zstandard_web': const PackageSpec(deps: ['zstandard_platform_interface']),
    'zstandard_cli': const PackageSpec(deps: []),
    'zstandard': const PackageSpec(deps: [
      'zstandard_platform_interface',
      'zstandard_android',
      'zstandard_ios',
      'zstandard_linux',
      'zstandard_macos',
      'zstandard_web',
      'zstandard_windows',
    ]),
  };
}
