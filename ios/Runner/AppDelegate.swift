import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Register the iOS live-screen capture bridge (MethodChannel +
    // EventChannel mirroring the Android MediaProjection contract).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenCapturePlugin") {
      ScreenCapturePlugin.register(with: registrar)
    }
  }
}
