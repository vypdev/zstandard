import Cocoa
import FlutterMacOS
import XCTest

/// Native (Swift) unit tests for the zstandard_macos example app.
class RunnerTests: XCTestCase {

  func testExample() {
    XCTAssertTrue(true, "Placeholder to keep test target valid")
  }

  func testZstandardMacOSExampleBundleLoads() {
    XCTAssertNotNil(Bundle.main.bundleIdentifier)
  }

  func testBundleExecutablePathExists() {
    XCTAssertNotNil(Bundle.main.executablePath)
  }

  @available(macOS 12.0, *)
  func testAsyncExample() async {
    let value = await Task { true }.value
    XCTAssertTrue(value)
  }
}
