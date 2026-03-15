// VM cannot load dart:js_interop; use stub so "flutter test" passes without Chrome.
import 'wasm_interop_test_impl.dart' if (dart.library.io) 'wasm_interop_test_stub.dart' as impl;

void main() => impl.main();
