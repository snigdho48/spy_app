import Foundation

/// Constants shared between the Runner app and the ScreenBroadcast upload
/// extension. This file must be a member of BOTH targets in Xcode.
///
/// The App Group id below MUST match the "App Groups" capability enabled on
/// BOTH targets'' entitlements. It is the only channel between the sandboxed
/// broadcast extension and the app.
enum SpyLoveBroadcast {
    /// App Group shared between the app and the broadcast extension.
    static let appGroupId = "group.org.hmg.spyLove"

    /// Atomic JPEG file (in the App Group container) holding the latest frame.
    static let frameFileName = "latest_frame.jpg"

    /// Darwin notifications (payload-less) coordinating the two sandboxes.
    static let frameReadyNotification = "org.hmg.spyLove.screenFrameReady"
    static let stopNotification = "org.hmg.spyLove.stopBroadcast"
    static let startedNotification = "org.hmg.spyLove.broadcastStarted"
    static let finishedNotification = "org.hmg.spyLove.broadcastFinished"

    static func frameFileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent(frameFileName)
    }
}
