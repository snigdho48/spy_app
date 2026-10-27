# Spy Love (Flutter)

Consent-based family monitoring client. UI follows the **Consent Horizon** Stitch design system (tokens in `lib/core/theme/`, visual references under `.cursor/stitch-phase1/`).

## Stack

| Concern | Choice |
|---------|--------|
| State | `provider` (`ChangeNotifier`) |
| Navigation | `AppNavigator` + `onGenerateRoute` |
| HTTP | `one_request` → `/api/v1/` |
| Realtime | WebSocket `/ws/v1/events/` |
| Maps | `flutter_map` |
| Fonts | Inter via `google_fonts` (bundle assets for offline — see release checklist) |

## Source layout

```
lib/
  main.dart            entry
  firebase_options.dart
  app/                 composition root (SpyLoveApp, providers, routes)
  core/                bootstrap, config, network, navigation, permissions, storage, theme
  shared/widgets/      design-system widgets with no feature types
  features/
    auth/              sign-in, session, Google sign-in
    consent/           pairing flow and the in-app screen-share consent prompt
    devices/           signed-in shell, device list, device detail, safe zones
    monitoring/        collectors, geofence, SIM, and screen share
    audit/
    subscription/
```

Screen share (capture bridge, session, live view) is `lib/features/monitoring/screen_share/`. The in-app Allow/Deny gate is `lib/features/consent/screen_share_consent_prompt.dart`.

Native capture stays on the platform package paths: Android `android/app/src/main/kotlin/org/hmg/spy_love/`, iOS `ios/Runner/ScreenCapturePlugin.swift`, `ios/ScreenBroadcast/`, and `ios/Shared/`. Channels are unchanged (`org.hmg.spy_love/monitoring`, `org.hmg.spy_love/screen_frames`). iOS Xcode steps: [ios/SCREEN_CAPTURE_iOS_SETUP.md](ios/SCREEN_CAPTURE_iOS_SETUP.md).

## Responsive layout

Breakpoints in `AppBreakpoints` (`lib/core/theme/app_tokens.dart`):

| Width | Layout |
|-------|--------|
| `< 600` | Compact (phone) |
| `600`–`< 1024` | Medium (tablet) |
| `≥ 1024` | Expanded (desktop-width) |

Helpers: `ResponsiveBody`, `TwoPaneLayout` in `lib/shared/widgets/responsive_scaffold.dart`. Content max width `1280`.

## Features wired to the API

- Pairing (initiate / complete) with consent scopes
- Device list, detail, activity feed, location map, SIM tab
- **Sharing pause / resume** (monitored owner) — does not change consent
- **Safe zones** CRUD + client geofence enter/exit (`location` consent)
- **Keyword watchlist** on Manage
- Optional device **`photo_url`** (https; client-loaded)
- Contact enrichment fields on call/SMS payloads when available

Contract paths live in `lib/core/constants/api_constants.dart` and must match the backend.

## Configure API

Defaults are dart-defines in `lib/core/config/app_config.dart`:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://YOUR_HOST/api/v1 \
  --dart-define=WS_BASE_URL=wss://YOUR_HOST/ws/v1/events/ \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID
```

Do not commit `.env`, `android/key.properties`, or keystores.

## Run

```bash
cd spy_love
flutter pub get
flutter run
```

Visual / Stitch notes: `.cursor/stitch-phase1/COMPARISON.md`.  
Release steps: [../docs/RELEASE_CHECKLIST.md](../docs/RELEASE_CHECKLIST.md).  
Signed Android APKs: [docs/RELEASE_APK.md](docs/RELEASE_APK.md).
