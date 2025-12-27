import Flutter
import UIKit

public class MoussaupdaterPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "moussa_updater/methods", binaryMessenger: registrar.messenger())
    let instance = MoussaupdaterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {

    case "checkAndMaybeUpdate":
      guard let args = call.arguments as? [String: Any] else {
        result(["action":"ERROR","platform":"ios","reason":"BAD_ARGS"])
        return
      }

      let minVersion = (args["minVersion"] as? String) ?? "0.0.0"
      let iosAppId = (args["iosAppId"] as? String) ?? ""

      let current = getCurrentVersion()
      let needsForce = isVersionLower(current, minVersion)

      if !needsForce {
        result([
          "action": "UP_TO_DATE",
          "platform": "ios",
          "currentVersion": current,
          "minVersion": minVersion
        ])
        return
      }

      // iOS: no in-app install. Force block + open store
      let storeUrl = iosAppId.isEmpty ? "" : "itms-apps://itunes.apple.com/app/id\(iosAppId)"
      result([
        "action": "FORCE_BLOCKED",
        "platform": "ios",
        "currentVersion": current,
        "minVersion": minVersion,
        "reason": "BELOW_MIN_VERSION",
        "storeUrl": storeUrl
      ])

    case "openStore":
      guard let args = call.arguments as? [String: Any] else { result(nil); return }
      let iosAppId = (args["iosAppId"] as? String) ?? ""
      openAppStore(appId: iosAppId)
      result(nil)

    case "completeFlexibleUpdate":
      // iOS not supported
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getCurrentVersion() -> String {
    return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
  }

  private func openAppStore(appId: String) {
    guard !appId.isEmpty else { return }
    if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appId)") {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }

  private func isVersionLower(_ current: String, _ min: String) -> Bool {
    func parse(_ v: String) -> [Int] {
      return v.split(separator: ".").map { Int($0) ?? 0 }
    }
    let a = parse(current)
    let b = parse(min)
    let n = max(a.count, b.count)
    for i in 0..<n {
      let ai = i < a.count ? a[i] : 0
      let bi = i < b.count ? b[i] : 0
      if ai < bi { return true }
      if ai > bi { return false }
    }
    return false
  }
}
