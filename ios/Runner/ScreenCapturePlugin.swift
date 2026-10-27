import Flutter
import UIKit
import ReplayKit
import ImageIO

/// iOS live-screen capture bridge. Mirrors the Android MediaProjection contract
/// so the shared Dart `ScreenCaptureBridge` / `ScreenShareService` work
/// unchanged:
///
///   MethodChannel `org.hmg.spy_love/monitoring`
///     - isScreenCaptureSupported            -> Bool
///     - startScreenCapture(fps,maxWidth,...) -> Bool  (presents the system
///         RPSystemBroadcastPickerView consent sheet; this is the consent gate)
///     - stopScreenCapture                    -> void
///   EventChannel  `org.hmg.spy_love/screen_frames`
///     emits { image: <base64 jpeg>, w: Int, h: Int } for every frame the
///     ScreenBroadcast upload extension writes into the shared App Group, plus a
///     control event { event: "broadcastStarted" } once the broadcast actually
///     begins.
///
/// Consent: no frame can flow until the user grants the OS broadcast sheet
/// (ReplayKit shows a persistent red recording indicator for the whole
/// session). The Dart ScreenShareService additionally requires an active
/// backend `screen` scope + an explicit in-app Allow, and drives the global red
/// in-app sharing banner, so the behaviour matches Android. There is
/// deliberately no covert path.
///
/// IMPORTANT (M1): ReplayKit cannot report the user's picker choice
/// synchronously, so `startScreenCapture` returns true once the consent sheet
/// has merely been *presented* — it does NOT mean sharing is active. The active
/// / "sharing" state is driven instead by the `broadcastStarted` Darwin
/// notification (surfaced to Dart as the `broadcastStarted` control event) and
/// cleared on `broadcastFinished` (surfaced as end-of-stream). If the user
/// cancels the picker, no `broadcastStarted` fires and no frames are emitted.
public class ScreenCapturePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private var pickerView: RPSystemBroadcastPickerView?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ScreenCapturePlugin()
        let method = FlutterMethodChannel(
            name: "org.hmg.spy_love/monitoring",
            binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: method)
        let event = FlutterEventChannel(
            name: "org.hmg.spy_love/screen_frames",
            binaryMessenger: registrar.messenger())
        event.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isScreenCaptureSupported":
            if #available(iOS 12.0, *) { result(true) } else { result(false) }
        case "startScreenCapture":
            startCapture(result: result)
        case "stopScreenCapture":
            stopCapture()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Consent gate: present the system broadcast picker

    private func startCapture(result: @escaping FlutterResult) {
        guard #available(iOS 12.0, *) else { result(false); return }
        DispatchQueue.main.async {
            let picker = RPSystemBroadcastPickerView(
                frame: CGRect(x: 0, y: 0, width: 60, height: 60))
            picker.preferredExtension = "org.hmg.spyLove.ScreenBroadcast"
            if #available(iOS 13.0, *) { picker.showsMicrophoneButton = false }
            if let window = Self.keyWindow() { window.addSubview(picker) }
            self.pickerView = picker
            // Programmatically tap the embedded button to raise the OS sheet.
            for subview in picker.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .touchUpInside)
                }
            }
            // NOTE: true == "sheet presented", NOT "sharing active". The active
            // state is driven by the broadcastStarted notification below.
            result(true)
        }
    }

    private func stopCapture() {
        // Ask the extension to finish (user tapped Stop in-app).
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(SpyLoveBroadcast.stopNotification as CFString),
            nil, nil, true)
        DispatchQueue.main.async {
            self.pickerView?.removeFromSuperview()
            self.pickerView = nil
        }
    }

    // MARK: - FlutterStreamHandler (frame delivery)

    public func onListen(withArguments arguments: Any?,
                         eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        addObservers()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        removeObservers()
        eventSink = nil
        return nil
    }

    private func addObservers() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        // Broadcast actually started: surface a control event so the Dart layer
        // can flip to the ACTIVE / red-banner state (M1). Presentation alone is
        // never enough.
        CFNotificationCenterAddObserver(
            center, Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let plugin = Unmanaged<ScreenCapturePlugin>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { plugin.eventSink?(["event": "broadcastStarted"]) }
            },
            SpyLoveBroadcast.startedNotification as CFString, nil, .deliverImmediately)
        CFNotificationCenterAddObserver(
            center, Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                Unmanaged<ScreenCapturePlugin>.fromOpaque(observer)
                    .takeUnretainedValue().emitLatestFrame()
            },
            SpyLoveBroadcast.frameReadyNotification as CFString, nil, .deliverImmediately)
        // Broadcast finished (user cancelled / stopped): end the stream so the
        // Dart layer clears the ACTIVE state.
        CFNotificationCenterAddObserver(
            center, Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let plugin = Unmanaged<ScreenCapturePlugin>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { plugin.eventSink?(FlutterEndOfEventStream) }
            },
            SpyLoveBroadcast.finishedNotification as CFString, nil, .deliverImmediately)
    }

    private func removeObservers() {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque())
    }

    private func emitLatestFrame() {
        guard let url = SpyLoveBroadcast.frameFileURL(),
              let data = try? Data(contentsOf: url), !data.isEmpty else { return }
        var width = 0
        var height = 0
        if let src = CGImageSourceCreateWithData(data as CFData, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
            width = (props[kCGImagePropertyPixelWidth] as? Int) ?? 0
            height = (props[kCGImagePropertyPixelHeight] as? Int) ?? 0
        }
        let b64 = data.base64EncodedString()
        DispatchQueue.main.async {
            self.eventSink?(["image": b64, "w": width, "h": height])
        }
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
