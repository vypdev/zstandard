// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tell the user where to find the real tests', () {
    print('---');
    print('Platform tests run as integration tests in example/integration_test/.');
    print('From repo root: ./scripts/ensure_macos_framework.sh');
    print('Then: cd example && flutter test integration_test/ -d macos');
    print('---');
  });
}