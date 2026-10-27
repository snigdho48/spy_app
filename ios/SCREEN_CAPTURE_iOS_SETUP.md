# iOS live screen capture (ReplayKit) — manual Xcode setup

The iOS native code for consent-scoped live screen monitoring is committed under
`ios/` but is **UNBUILT and UNVERIFIED**: it cannot be compiled from Windows
(no Xcode). The source is written to ReplayKit conventions and mirrors the
Android MediaProjection contract. Finish the wiring on a Mac with Xcode using
the steps below.

## What already exists in the repo

- `ios/Shared/SpyLoveBroadcastShared.swift` — App Group id, shared frame file
  name, and Darwin notification names. Must be a member of **both** the Runner
  app target and the broadcast extension target.
- `ios/ScreenBroadcast/SampleHandler.swift` — `RPBroadcastSampleHandler`:
  throttles to ~8fps, downscales to maxWidth 720, JPEG-encodes at ~0.4, writes
  each frame atomically into the App Group container, and posts a Darwin
  notification.
- `ios/ScreenBroadcast/Info.plist` — `NSExtensionPointIdentifier =
  com.apple.broadcast-services-upload`, principal class
  `$(PRODUCT_MODULE_NAME).SampleHandler`, `RPBroadcastProcessMode =
  RPBroadcastProcessModeSampleBuffer`.
- `ios/ScreenBroadcast/ScreenBroadcast.entitlements` — App Group
  `group.org.hmg.spyLove`.
- `ios/Runner/ScreenCapturePlugin.swift` — registers MethodChannel
  `org.hmg.spy_love/monitoring` and EventChannel `org.hmg.spy_love/screen_frames`;
  `startScreenCapture` presents `RPSystemBroadcastPickerView` (the consent gate).
- `ios/Runner/AppDelegate.swift` — already registers `ScreenCapturePlugin`.
- `ios/Runner/Runner.entitlements` — App Group `group.org.hmg.spyLove` for the app.

App bundle id: `org.hmg.spyLove`. Extension bundle id (target below):
`org.hmg.spyLove.ScreenBroadcast`. App Group: `group.org.hmg.spyLove`.
Deployment target: iOS 13.0 (ReplayKit broadcast picker needs iOS 12+).

## Manual Xcode steps (Mac required)

1. **Open the workspace:** `ios/Runner.xcworkspace` (run `pod install` first if
   CocoaPods is used).

2. **Create the broadcast extension target:**
   - File ▸ New ▸ Target… ▸ **Broadcast Upload Extension**.
   - Product Name: `ScreenBroadcast`. Uncheck "Include UI Extension".
   - Bundle id: `org.hmg.spyLove.ScreenBroadcast`. Embed in the Runner app.
   - Xcode generates a template `SampleHandler.swift` + `Info.plist`. **Delete
     the generated files from disk** and instead add the repo's
     `ios/ScreenBroadcast/SampleHandler.swift` and `ios/ScreenBroadcast/Info.plist`
     to the new target (or overwrite the generated ones with these). Set the
     target's Info.plist build setting to `ScreenBroadcast/Info.plist`.

3. **Add the shared file to both targets:** add
   `ios/Shared/SpyLoveBroadcastShared.swift` to **Target Membership** of BOTH
   `Runner` and `ScreenBroadcast`.

4. **Add the plugin file to Runner:** ensure
   `ios/Runner/ScreenCapturePlugin.swift` is a member of the `Runner` target
   (new file added outside Xcode — add it to the project/target).

5. **Enable the App Group capability on BOTH targets** (Signing & Capabilities ▸
   + Capability ▸ App Groups) and check/add `group.org.hmg.spyLove` on each.
   Point each target's **Code Signing Entitlements** build setting at the repo
   entitlements files: Runner ▸ `Runner/Runner.entitlements`; ScreenBroadcast ▸
   `ScreenBroadcast/ScreenBroadcast.entitlements`. (The group id must be
   registered on your Apple Developer account and match the provisioning
   profiles.)

6. **Info.plist keys:**
   - Extension `ScreenBroadcast/Info.plist` already has the required
     `NSExtension` dict (verify the principal class resolves to
     `<ExtensionModuleName>.SampleHandler`).
   - The Runner app needs **no** new usage-description string for ReplayKit
     (the OS broadcast picker is the consent surface). If you later add
     microphone capture, add `NSMicrophoneUsageDescription`.

7. **Build & run on a real device** (ReplayKit broadcast does not work in the
   Simulator). In-app: tapping "share screen" calls `startScreenCapture`, which
   raises the system broadcast sheet; pick "Spy Love Screen" and Start Broadcast.

## Behaviour / consent notes to verify on device

- No frames flow until the user grants the system broadcast sheet; iOS shows a
  persistent red recording indicator for the whole session. The Dart
  `ScreenShareService` additionally requires an active backend `screen` scope and
  drives the global red in-app "screen is being shared" banner. No covert path.
- `startScreenCapture` returns `true` once the consent sheet is **presented**
  (ReplayKit cannot report the user's choice synchronously). Frames begin only
  after the extension actually starts. If the user cancels, no frames are emitted
  and the WS session simply stays idle until stopped — confirm the app-side
  timeout/stop behaviour is acceptable.
- Frame transport: extension writes JPEG to the App Group file + posts
  `screenFrameReady`; the app reads the file, derives w/h from the JPEG, base64s
  it, and emits `{image,w,h}` on the EventChannel — identical to Android.
- `stopScreenCapture` posts `stopBroadcast`; the extension calls
  `finishBroadcastWithError` to end the system broadcast.
