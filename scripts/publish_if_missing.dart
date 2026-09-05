// ignore_for_file: avoid_print
/// Publishes a package unless this exact immutable version is already on pub.dev.
/// Usage: dart run scripts/publish_if_missing.dart <package> <version>

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run scripts/publish_if_missing.dart <package> <version>',
    );
    exitCode = 2;
    return;
  }

  final package = args[0];
  final version = args[1];
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  var alreadyPublished = false;
  try {
    final request = await client.getUrl(
      Uri.parse('https://pub.dev/api/packages/$package'),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == HttpStatus.ok) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final versions = (json['versions'] as List<dynamic>? ?? const []);
      alreadyPublished = versions.any(
        (entry) => entry is Map<String, dynamic> && entry['version'] == version,
      );
    }
  } catch (error) {
    stderr.writeln('Could not query pub.dev before publishing: $error');
    exitCode = 1;
    return;
  } finally {
    client.close(force: true);
  }

  if (alreadyPublished) {
    print('$package $version is already published; continuing safely.');
    return;
  }

  final result = await Process.run(
    'dart',
    ['pub', 'publish', '-f'],
    workingDirectory: package,
    runInShell: true,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exitCode = result.exitCode;
}
