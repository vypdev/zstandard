// VM cannot load dart:js_interop; use stub so "flutter test" passes without Chrome.
import 'zstandard_web_test_impl.dart' if (dart.library.io) 'zstandard_web_test_stub.dart' as impl;

void main() => impl.main();
