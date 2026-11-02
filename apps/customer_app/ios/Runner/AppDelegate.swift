import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let encodedDefines = Bundle.main.object(forInfoDictionaryKey: "BThereDartDefines") as? String ?? ""
    for encoded in encodedDefines.split(separator: ",") {
      guard let data = Data(base64Encoded: String(encoded)),
            let define = String(data: data, encoding: .utf8),
            define.hasPrefix("BTHERE_GOOGLE_MAPS_API_KEY=") else { continue }
      let key = String(define.dropFirst("BTHERE_GOOGLE_MAPS_API_KEY=".count))
      if !key.isEmpty { GMSServices.provideAPIKey(key) }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
