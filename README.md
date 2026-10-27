# Spy Love (Flutter)

Consent-based family monitoring client. UI follows the **Consent Horizon** Stitch design system (tokens in `lib/app/core/theme/`, visual references under `.cursor/stitch-phase1/`).

## Stack

| Concern | Choice |
|---------|--------|
| State | `provider` (`ChangeNotifier`) |
| Navigation | `AppNavigator` + `onGenerateRoute` |
| HTTP | `one_request` → `/api/v1/` |
| Realtime | WebSocket `/ws/v1/events/` |
| Maps | `flutter_map` |
| Fonts | Inter via `google_fonts` (bundle assets for offline — see release checklist) |

## Responsive layout

Breakpoints in `AppBreakpoints` (`lib/app/core/theme/app_tokens.dart`):

| Width | Layout |
|-------|--------|
| `< 600` | Compact (phone) |
| `600`–`< 1024` | Medium (tablet) |
| `≥ 1024` | Expanded (desktop-width) |

Helpers: `ResponsiveBody`, `TwoPaneLayout` in `lib/app/core/widgets/responsive_scaffold.dart`. Content max width `1280`.

## Features wired to the API

- Pairing (initiate / complete) with consent scopes
- Device list, detail, activity feed, location map, SIM tab
- **Sharing pause / resume** (monitored owner) — does not change consent
- **Safe zones** CRUD + client geofence enter/exit (`location` consent)
- **Keyword watchlist** on Manage
- Optional device **`photo_url`** (https; client-loaded)
- Contact enrichment fields on call/SMS payloads when available

Contract paths live in `lib/app/core/constants/api_constants.dart` and must match the backend.

## Configure API

Defaults are dart-defines in `lib/app/core/config/app_config.dart`:

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
