import Flutter
import UIKit
import XCTest

/// Native (Swift) unit tests for the zstandard_ios example app.
/// Compression and decompression behaviour are tested by the Dart integration tests
/// in the main zstandard plugin (example/integration_test/). These tests verify
/// the test bundle runs and the app is set up correctly.
class RunnerTests: XCTestCase {

  func testExample() {
    XCTAssertTrue(true, "Placeholder to keep test target valid")
  }

  func testZstandardIOSExampleBundleLoads() {
    // Verify the test bundle and app dependencies are loadable.
    XCTAssertNotNil(Bundle.main.bundleIdentifier)
  }

  func testBundleExecutablePathExists() {
    XCTAssertNotNil(Bundle.main.executablePath)
  }

  @available(iOS 13.0, *)
  func testAsyncExample() async {
    // Async test: verify we can await without blocking.
    let value = await Task { true }.value
    XCTAssertTrue(value)
  }
}
