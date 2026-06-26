import Flutter
import UIKit

// When Gobackend.xcframework is embedded, uncomment:
// import Gobackend

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "com.bitly/backend"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerBackendChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerBackendChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      DispatchQueue.global(qos: .background).async {
        switch call.method {
        case "initGoBackend":
          let dbPath = (call.arguments as? [String: Any])?["db_path"] as? String ?? ""
          let res = self.initGoBackend(dbPath: dbPath)
          DispatchQueue.main.async { result(res) }

        case "getApplicationDocumentsDirectory":
          let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
          DispatchQueue.main.async { result(dir) }

        default:
          let paramsStr = self.jsonParams(from: call.arguments)
          let res = self.invokeRPC(method: call.method, params: paramsStr)
          DispatchQueue.main.async { result(res) }
        }
      }
    }
  }

  /// When Gobackend.xcframework is embedded, this calls the Go backend.
  /// For now it returns a stub so Flutter can validate the integration.
  private func initGoBackend(dbPath: String) -> String {
    // TODO: GobackendInitBackend(dbPath)
    // Until the framework is embedded in Xcode, return stub:
    return "stub_gobackend_not_embedded"
  }

  private func invokeRPC(method: String, params: String) -> String? {
    // TODO: return GobackendInvokeRPC(method, params)
    return nil
  }

  private func jsonParams(from arguments: Any?) -> String {
    guard let args = arguments as? [String: Any], !args.isEmpty else { return "" }
    if let data = try? JSONSerialization.data(withJSONObject: args, options: []) {
      return String(data: data, encoding: .utf8) ?? ""
    }
    return ""
  }
}
