import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zstandard_platform_interface/src/zstandard_platform_interface_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('plugins.flutter.io/zstandard');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion throws MissingPluginException when no handler set',
      () async {
    // Ensure no mock handler is set for the plugin's channel.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    final platform = MethodChannelZstandardPlatform();

    await expectLater(
      () async => await platform.getPlatformVersion(),
      throwsA(isA<MissingPluginException>()),
    );
  });

  test('getPlatformVersion returns value when handler is set', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getPlatformVersion') {
        return 'TestVersion';
      }
      return null;
    });

    final platform = MethodChannelZstandardPlatform();
    final version = await platform.getPlatformVersion();

    expect(version, 'TestVersion');
  });
}
