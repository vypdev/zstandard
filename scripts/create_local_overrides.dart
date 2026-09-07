import 'dart:io';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart scripts/create_local_overrides.dart '
      '<package> [external-native-path]',
    );
    exitCode = 2;
    return;
  }

  final repositoryRoot = File.fromUri(Platform.script).parent.parent;
  final package = arguments.first;
  final externalNative = arguments.length == 2 ? arguments[1] : null;

  final packageNative = externalNative ?? '../zstandard_native';
  final exampleNative = externalNative ?? '../../zstandard_native';

  switch (package) {
    case 'zstandard_native':
    case 'zstandard_platform_interface':
      return;
    case 'zstandard_cli':
      _writeOverrides(repositoryRoot, '$package/pubspec_overrides.yaml', {
        'zstandard_native': packageNative,
      });
    case 'zstandard_android':
    case 'zstandard_ios':
    case 'zstandard_linux':
    case 'zstandard_macos':
    case 'zstandard_web':
    case 'zstandard_windows':
      final dependencies = {
        'zstandard_native': packageNative,
        'zstandard_platform_interface': '../zstandard_platform_interface',
      };
      _writeOverrides(
        repositoryRoot,
        '$package/pubspec_overrides.yaml',
        dependencies,
      );
      final example = Directory.fromUri(
        repositoryRoot.uri.resolve('$package/example/'),
      );
      if (example.existsSync()) {
        _writeOverrides(
          repositoryRoot,
          '$package/example/pubspec_overrides.yaml',
          {
            'zstandard_native': exampleNative,
            'zstandard_platform_interface':
                '../../zstandard_platform_interface',
          },
        );
      }
      final legacyExample = Directory.fromUri(
        repositoryRoot.uri.resolve('$package/example_legacy/'),
      );
      if (package == 'zstandard_android' && legacyExample.existsSync()) {
        _writeOverrides(
          repositoryRoot,
          '$package/example_legacy/pubspec_overrides.yaml',
          {
            'zstandard_native': exampleNative,
            'zstandard_platform_interface':
                '../../zstandard_platform_interface',
          },
        );
      }
    case 'zstandard':
      _writeOverrides(repositoryRoot, '$package/pubspec_overrides.yaml', {
        for (final dependency in const [
          'zstandard_android',
          'zstandard_ios',
          'zstandard_linux',
          'zstandard_macos',
          'zstandard_native',
          'zstandard_platform_interface',
          'zstandard_web',
          'zstandard_windows',
        ])
          dependency: '../$dependency',
      });
    default:
      stderr.writeln('Unsupported package: $package');
      exitCode = 2;
  }
}

void _writeOverrides(
  Directory repositoryRoot,
  String relativePath,
  Map<String, String> dependencies,
) {
  final output = StringBuffer('dependency_overrides:\n');
  for (final MapEntry(:key, :value) in dependencies.entries) {
    final portablePath = value.replaceAll('\\', '/').replaceAll("'", "''");
    output
      ..writeln('  $key:')
      ..writeln("    path: '$portablePath'");
  }
  File.fromUri(repositoryRoot.uri.resolve(relativePath))
      .writeAsStringSync(output.toString());
}
