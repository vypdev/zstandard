import Flutter
import UIKit
#if SWIFT_PACKAGE
import zstandard_ffi
#endif

public class ZstandardIosPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if SWIFT_PACKAGE
    ZstandardNativeRetainSymbols()
    #endif
    let channel = FlutterMethodChannel(name: "plugins.flutter.io/zstandard", binaryMessenger: registrar.messenger())
    let instance = ZstandardIosPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
