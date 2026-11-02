import Cocoa
import FlutterMacOS
#if SWIFT_PACKAGE
import zstandard_ffi
#endif

public class ZstandardMacosPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if SWIFT_PACKAGE
    ZstandardNativeRetainSymbols()
    #endif
    let channel = FlutterMethodChannel(name: "plugins.flutter.io/zstandard", binaryMessenger: registrar.messenger)
    let instance = ZstandardMacosPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
