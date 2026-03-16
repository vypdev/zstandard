import 'dart:async';

import 'package:leak_tracker_testing/leak_tracker_testing.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  return testMain();
}
