// VM cannot load dart:js_interop; use stub so "flutter test" passes without Chrome.
import 'properties_test_impl.dart' if (dart.library.io) 'properties_test_stub.dart' as impl;

void main() => impl.main();
