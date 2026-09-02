# zstandard_platform_web_example

Demonstrates how to use the zstandard_platform_web plugin.

Also, this is a test app for manual testing and automated integration testing
of this platform implementation.

## Testing

This package uses `package:integration_test` to run its tests in a web browser.

See [Plugin Tests > Web Tests](https://github.com/flutter/flutter/blob/master/docs/ecosystem/testing/Plugin-Tests.md#web-tests)
in the Flutter documentation for instructions to set up and run the tests in this package.

Check [flutter.dev > Integration testing](https://docs.flutter.dev/testing/integration-tests)
for more info.

```bash
chromedriver --port=4444
```

```bash
flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/zstandard_web_integration_test.dart \
    -d web-server --web-port=8080
```
