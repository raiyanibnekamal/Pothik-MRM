import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let gps = BackgroundLocationManager()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let methods = FlutterMethodChannel(
      name: "com.bdrideshare/gps",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    methods.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "warmUp":
        result(nil)
      case "start":
        let args = call.arguments as? [String: Any]
        let interval = args?["intervalMs"] as? Int ?? 3000
        let displacement = args?["displacementM"] as? Int ?? 10
        self?.gps.start(intervalMs: interval, displacementM: Double(displacement))
        result(nil)
      case "stop":
        self?.gps.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
