import 'package:flutter_test/flutter_test.dart';

/// Stub entrypoint when running on VM. Real tests run on Chrome via wasm_interop_test_impl.dart.
void main() {
  test('WASM interop tests', () {}, skip: 'Only runs on web (flutter test -d chrome)');
}
