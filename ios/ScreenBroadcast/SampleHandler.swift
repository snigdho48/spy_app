import ReplayKit
import CoreImage
import UIKit

/// ReplayKit Broadcast Upload Extension entry point.
///
/// Consent model: this extension is only ever launched by iOS AFTER the user
/// grants the system broadcast picker (RPSystemBroadcastPickerView, presented
/// by the app via the `startScreenCapture` MethodChannel call). While it runs,
/// ReplayKit shows a persistent red recording indicator / status bar, so the
/// OS-level "your screen is being shared" signal is always visible. There is no
/// covert path: iOS will not start this extension without the explicit grant.
///
/// It mirrors the Android MediaProjection defaults: throttle to ~8 fps,
/// downscale to maxWidth 720, JPEG-encode at quality ~0.4. Each frame is written
/// atomically into the shared App Group container and announced with a Darwin
/// notification so the app can base64 it and push it over the existing WS
/// contract via the Dart ScreenShareService.
class SampleHandler: RPBroadcastSampleHandler {

    private let targetFps: Double = 8
    private let maxWidth: CGFloat = 720
    private let jpegQuality: CGFloat = 0.4

    private var lastFrameTime: CFTimeInterval = 0
    private let ciContext = CIContext(options: nil)

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        postDarwin(SpyLoveBroadcast.startedNotification)
        // Let the app ask us to stop (user tapped "Stop sharing" in-app).
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
                handler.finishGracefully()
            },
            SpyLoveBroadcast.stopNotification as CFString,
            nil, .deliverImmediately)
    }

    override func broadcastFinished() {
        postDarwin(SpyLoveBroadcast.finishedNotification)
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque())
    }

    private func finishGracefully() {
        finishBroadcastWithError(NSError(
            domain: "org.hmg.spyLove",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Screen sharing stopped."]))
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }

        // Throttle to ~targetFps.
        let now = CACurrentMediaTime()
        if now - lastFrameTime < (1.0 / targetFps) { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        autoreleasepool {
            guard let jpeg = encodeJPEG(from: pixelBuffer) else { return }
            writeFrame(jpeg)
        }
    }

    private func encodeJPEG(from pixelBuffer: CVPixelBuffer) -> Data? {
        let srcWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let srcHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        guard srcWidth > 0, srcHeight > 0 else { return nil }

        let scale = min(1.0, maxWidth / srcWidth)
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        if scale < 1.0 {
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: jpegQuality)
    }

    private func writeFrame(_ data: Data) {
        guard let url = SpyLoveBroadcast.frameFileURL() else { return }
        // .atomic => write to temp + rename, so the app never reads a torn file.
        if (try? data.write(to: url, options: .atomic)) != nil {
            postDarwin(SpyLoveBroadcast.frameReadyNotification)
        }
    }

    private func postDarwin(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil, nil, true)
    }
}
