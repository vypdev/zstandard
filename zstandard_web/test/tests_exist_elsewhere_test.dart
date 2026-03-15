// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tell the user where to find the real tests', () {
    print('---');
    print('Web tests require Chrome: flutter test -d chrome');
    print('From repo root: ./scripts/test_web_integration.sh');
    print('See example/integration_test/ for full app integration tests.');
    print('---');
  });
}