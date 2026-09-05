// ignore_for_file: avoid_print
/// Waits until a package/version is visible in the pub.dev API.
/// Usage: dart run scripts/wait_for_pub_version.dart <package> <version> [seconds]

import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length < 2 || args.length > 3) {
    stderr.writeln(
      'Usage: dart run scripts/wait_for_pub_version.dart <package> <version> [seconds]',
    );
    exitCode = 2;
    return;
  }

  final package = args[0];
  final version = args[1];
  final timeoutSeconds = args.length == 3 ? int.tryParse(args[2]) : 1200;
  if (timeoutSeconds == null || timeoutSeconds <= 0) {
    stderr.writeln('Timeout must be a positive number of seconds.');
    exitCode = 2;
    return;
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
  try {
    while (DateTime.now().isBefore(deadline)) {
      try {
        final request = await client.getUrl(
          Uri.parse('https://pub.dev/api/packages/$package'),
        );
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        if (response.statusCode == HttpStatus.ok) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          final versions = (json['versions'] as List<dynamic>? ?? const []);
          final found = versions.any(
            (entry) =>
                entry is Map<String, dynamic> && entry['version'] == version,
          );
          if (found) {
            print('$package $version is available on pub.dev.');
            return;
          }
        }
      } catch (error) {
        print('pub.dev check failed temporarily: $error');
      }
      print('Waiting for $package $version to become visible on pub.dev...');
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  } finally {
    client.close(force: true);
  }

  stderr.writeln('Timed out waiting for $package $version on pub.dev.');
  exitCode = 1;
}
