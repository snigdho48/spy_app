# App changelog

All meaningful Flutter app changes go here. Newest entries first.

Agents: update this file at the end of every coding turn that touches `spy_love/`. Include **Time** `YYYY-MM-DD HH:MM (UTC+6)`, Author, Model, Mode, Summary, Files, and Impact.

## [Unreleased]

### Added � 2026-10-26

**Time:** 2026-10-26 16:10 (UTC+6)
**Author:** Grok Bot (executor)
**Model:** Grok Bot
**Mode:** high
**Issue:** n/a

**Summary:** iOS ReplayKit path for live screen monitoring, to parity with the Android MediaProjection capture. New ReplayKit Broadcast Upload Extension (`ios/ScreenBroadcast`) throttles to ~8fps, downscales to maxWidth 720, JPEG-encodes at ~0.4 (matching Android defaults), and writes frames atomically into a shared App Group (`group.org.hmg.spyLove`), announced via Darwin notifications. New Runner `ScreenCapturePlugin` registers the MethodChannel `org.hmg.spy_love/monitoring` (`isScreenCaptureSupported` true on iOS 12+, `startScreenCapture` presents `RPSystemBroadcastPickerView` = the consent gate, `stopScreenCapture`) and the EventChannel `org.hmg.spy_love/screen_frames` (`{image,w,h}`), so the existing Dart `ScreenShareService` streams over the same WS contract unchanged. Flutter `ScreenCaptureBridge` doc updated and `isSupported()` now returns true on iOS. Consent intact: frames only after the OS broadcast grant + active backend `screen` scope; global red sharing indicator applies on iOS too. No covert path.

**Files:**
- `ios/Shared/SpyLoveBroadcastShared.swift` (new; App Group + Darwin constants, member of both targets)
- `ios/ScreenBroadcast/SampleHandler.swift`, `Info.plist`, `ScreenBroadcast.entitlements` (new extension target)
- `ios/Runner/ScreenCapturePlugin.swift` (new), `AppDelegate.swift` (register plugin), `Runner.entitlements` (new; App Group)
- `lib/app/core/monitoring/screen_capture_bridge.dart` (doc: iOS now supported)
- `ios/SCREEN_CAPTURE_iOS_SETUP.md` (manual Xcode steps)

**Impact:** New iOS native feature. UNBUILT/UNVERIFIED � iOS cannot be built from Windows (no Xcode); code written per ReplayKit conventions. Requires a Mac + Xcode to create the extension target, enable the App Group on both targets, add the new Swift files to targets, and set Info.plist keys per `ios/SCREEN_CAPTURE_iOS_SETUP.md`. Android native and Flutter consent UI untouched; no forbidden deps added.

### Added � 2026-10-26

**Time:** 2026-10-26 15:31 (UTC+6)
**Author:** Grok Bot (executor)
**Model:** Grok Bot
**Mode:** high
**Issue:** n/a

**Summary:** Consent-scoped live screen monitoring (Flutter + Android native). Added 11th `screen` ConsentScope (auto-shown in pairing). Monitored side: ScreenShareService watches for requests, requires OS MediaProjection grant, captures via Android foreground service, relays base64 JPEG frames over per-session WS; persistent red `ScreenSharingIndicator` banner mounted globally. Monitor side: new `Live screen` tab requests a session and renders frames via Image.memory. No forbidden deps added; HTTP via one_request, WS via OneRequest.socket. Android: MediaProjection capture + foreground service (mediaProjection type) + EventChannel frames; iOS noted as follow-up (ReplayKit), not implemented.

**Files:**
- `lib/app/modules/pairing/models/consent_scope.dart` (screen scope)
- `lib/app/modules/device_detail/models/screen_share_session.dart`
- `lib/app/modules/device_detail/repositories/screen_share_repository.dart`
- `lib/app/modules/device_detail/controllers/live_screen_controller.dart`
- `lib/app/modules/device_detail/views/live_screen_tab.dart`, `device_detail_view.dart` (8th tab)
- `lib/app/core/network/screen_stream_client.dart`
- `lib/app/core/monitoring/screen_capture_bridge.dart`, `screen_share_service.dart`, `screen_sharing_indicator.dart`, `monitoring_service.dart`
- `lib/app/core/constants/api_constants.dart`, `core/config/app_config.dart`, `app.dart`, `app_providers.dart`
- `android/.../ScreenCapture.kt` (new), `MonitoringPlugin.kt`, `MainActivity.kt`, `AndroidManifest.xml`

**Impact:** New feature across Flutter + Android native. `flutter analyze`: No issues found. No covert capture path; requires explicit consent + OS grant + visible indicator.

### Changed — 2026-10-16

**Time:** 2026-10-16 15:25 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** medium
**Issue:** n/a

**Summary:** App README + Flutter architecture docs describe Consent Horizon UI, breakpoints (600/1024), pause/zones/keywords/photo_url; release checklist covers Android signing, permissions, dart-defines, Inter offline bundling.

**Files:**
- `spy_love/README.md`
- `docs/architecture/FLUTTER_ARCHITECTURE.md`, `docs/RELEASE_CHECKLIST.md` (repo `docs/`)

**Impact:** Documentation only.

### Changed — 2026-10-16

**Time:** 2026-10-16 15:10 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Pass 2 Stitch visual — auth/pairing hub/overview/map/SIM/care/audit/event/remove/permissions/subscriptions goldens at 412×915 & 800×1280 light+dark; UI fixes; COMPARISON.md Inter `flutter run` note.

**Files:**
- `lib/app/modules/pairing/views/pairing_start_view.dart`
- `lib/app/modules/auth/views/auth_view.dart`
- `lib/app/modules/device_detail/views/device_detail_view.dart`, `location_tab_view.dart`, `sim_tab_view.dart`
- `test/stitch_pass2_visual_test.dart`, `test/goldens/pass2/`
- `.cursor/stitch-phase1/COMPARISON.md`, `app-captures/pass2/`

**Impact:** App UI + visual regression goldens.

### Changed — 2026-10-16

**Time:** 2026-10-16 14:55 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Re-downloaded 31 Stitch screens into `.cursor/stitch-phase1/`; pixel pass on hero density, Family Circle dual progress, feed chrome, badge/chip denser pills; widget goldens at 412×915; COMPARISON.md for unmatched items.

**Files:**
- `.cursor/stitch-phase1/*.png`, `MANIFEST.md`, `COMPARISON.md`, `app-captures/`
- `lib/app/core/widgets/status_badge.dart`, `metric_card.dart`, `family_circle_switcher.dart`, `app_button.dart`, `device_list_tile.dart`
- `lib/app/modules/dashboard/views/home_tab.dart`
- `lib/app/modules/device_detail/views/activity_feed_tab.dart`
- `test/stitch_visual_compare_test.dart`, `test/goldens/`

**Impact:** App UI vs Stitch; no API change.

### Fixed — 2026-10-16

**Time:** 2026-10-16 14:40 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Offline polish — OfflineBanner retry on Home/Devices/Account/Auth; ConnectionErrorState copy; PageIntro/SectionHeader spacing. Stitch PNGs absent under `.cursor/stitch-phase1/`.

**Files:**
- `lib/app/core/widgets/app_states.dart`, `app_page.dart`, `section_header.dart`
- `lib/app/modules/dashboard/views/home_tab.dart`, `devices_tab.dart`, `account_tab.dart`
- `lib/app/modules/auth/views/auth_view.dart`

**Impact:** App UI offline + typography only.

### Added — 2026-10-16

**Time:** 2026-10-16 14:35 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Device avatars — DeviceAvatar shows https `photo_url` with initials fallback on home device rows and Family Circle stack.

**Files:**
- `lib/app/modules/dashboard/models/device_model.dart`, `repositories/device_repository.dart`
- `lib/app/core/widgets/device_avatar.dart`, `device_list_tile.dart`, `family_circle_switcher.dart`

**Impact:** App renders client-fetched photo URLs only (no server proxy).

### Added — 2026-10-16

**Time:** 2026-10-16 14:28 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Keyword watchlist — KeywordRepository + Manage sheet on SMS/Messages feed; chips and flagged filter use GET `/devices/keywords/`.

**Files:**
- `lib/app/core/constants/api_constants.dart`
- `lib/app/modules/dashboard/models/keyword_model.dart`, `repositories/keyword_repository.dart`
- `lib/app/modules/device_detail/views/activity_feed_tab.dart`
- `lib/app/app_providers.dart`

**Impact:** App + API client for keyword CRUD.

### Added — 2026-10-16

**Time:** 2026-10-16 14:22 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Phone-side geofence — MonitoringService loads SafeZones, emits geofence.enter/exit via events batch when crossing radius; skipped while sharing paused; location consent still server-enforced.

**Files:**
- `lib/app/core/monitoring/monitoring_service.dart`, `geofence_math.dart`
- `lib/app/app_providers.dart` — inject SafeZoneRepository
- `test/geofence_math_test.dart`

**Impact:** App emits geofence events against existing API.

### Fixed — 2026-10-16

**Time:** 2026-10-16 14:19 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Responsive layout pass — AdaptiveMetricRow stacks on narrow widths; MetricCard/DeviceListTile ellipsis; 48px tap targets; ScaledTextScope allows 1.5; responsive_layout_test across 360/412/800 × light/dark × 1.0/1.5.

**Files:**
- `lib/app/core/widgets/adaptive_metric_row.dart`, `metric_card.dart`, `device_list_tile.dart`, `app_button.dart`, `responsive_scaffold.dart`
- `lib/app/modules/dashboard/views/home_tab.dart`, `device_detail/views/activity_feed_tab.dart`
- `lib/app/core/theme/app_theme.dart`, `lib/app/core/widgets/family_circle_switcher.dart`
- `test/responsive_layout_test.dart`

**Impact:** App UI layout/accessibility. No API change.

### Added — 2026-10-16

**Time:** 2026-10-16 14:14 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Phase C contact fields — ContactPayload on events; Calls/SMS rows use https photo or initials avatar; Known/Flagged/Redacted badges; EventPresentation prefers contact_name. Keyword Manage skipped (no API).

**Files:**
- `lib/app/modules/device_detail/models/device_event_model.dart`
- `lib/app/modules/device_detail/views/activity_feed_tab.dart`
- `lib/app/modules/device_detail/views/event_detail_view.dart`

**Impact:** App maps new call/sms payload fields from existing events API.

### Added — 2026-10-16

**Time:** 2026-10-16 14:06 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Phase B safe zones + place names — api_constants/repo/model, Account CRUD card, Care/Home/Location show place_name/zone_name with coords fallback. Provider + one_request only.

**Files:**
- `lib/app/core/constants/api_constants.dart`
- `lib/app/modules/dashboard/models/safe_zone_model.dart`
- `lib/app/modules/dashboard/repositories/safe_zone_repository.dart`
- `lib/app/modules/dashboard/views/safe_zones_card.dart`, `account_tab.dart`
- `lib/app/modules/dashboard/controllers/dashboard_controller.dart`
- `lib/app/modules/device_detail/models/location_point.dart`
- `lib/app/modules/device_detail/views/device_care_tab.dart`, `location_tab_view.dart`
- `lib/app/app_providers.dart`

**Impact:** App + API client for SafeZone CRUD and place labels.

### Added — 2026-10-15

**Time:** 2026-10-15 20:05 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Phase A pause sharing UI — SharingState model, owned pause/resume API constants + repo, MonitoringService drops uploads while paused, Account owner pause/resume with countdown, monitor banner on Overview/Care, WS device_status handling.

**Files:**
- `lib/app/modules/dashboard/models/device_model.dart` — SharingState
- `lib/app/core/constants/api_constants.dart` — pause/resume paths
- `lib/app/modules/dashboard/repositories/device_repository.dart`
- `lib/app/core/monitoring/monitoring_service.dart`
- `lib/app/modules/dashboard/views/sharing_pause_card.dart`, `account_tab.dart`
- `lib/app/core/widgets/sharing_paused_banner.dart`
- `lib/app/modules/device_detail/` — controller + Overview/Care banner
- `lib/app/core/network/event_stream_client.dart` — device_status

**Impact:** App + API client contract for pause sharing. one_request only.

### Changed — 2026-10-15

**Time:** 2026-10-15 19:56 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Home/Devices rows — battery + geofence sub-rows from latest `battery`/`location` events via existing events API; no avatar collage (API has no photo URLs).

**Files:**
- `lib/app/modules/dashboard/controllers/dashboard_controller.dart`
- `lib/app/modules/dashboard/models/device_home_snapshot.dart`
- `lib/app/core/widgets/device_list_tile.dart`
- `lib/app/modules/dashboard/views/home_tab.dart`, `devices_tab.dart`
- `lib/app/app_providers.dart`

**Impact:** Extra lightweight event GETs for first 4 devices. No new endpoints. Avatar collage skipped.

### Changed — 2026-10-15

**Time:** 2026-10-15 19:54 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Soft/permanent remove dialog now blurs the device-detail backdrop (`BackdropFilter` + `showGeneralDialog`).

**Files:**
- `lib/app/core/widgets/confirm_device_action_sheet.dart`

**Impact:** UI only.

### Changed — 2026-10-15

**Time:** 2026-10-15 19:53 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Device care — safe-zone strip from latest location, masked IMEI, Pause sharing 1 hour disabled + TODO (no pause endpoint).

**Files:**
- `lib/app/modules/device_detail/views/device_care_tab.dart`

**Impact:** UI only. Pause remains unwired until `/api/v1/` gains a pause route.

### Changed — 2026-10-15

**Time:** 2026-10-15 19:52 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Pairing initiate — heart-centered QR (ECC H), handshake-channel chrome, platform share sheet via `share_plus` for SMS/WhatsApp text.

**Files:**
- `lib/app/modules/pairing/views/pairing_initiate_view.dart`
- `pubspec.yaml` — share_plus

**Impact:** UI + share_plus. No new backend share APIs.

### Changed — 2026-10-15

**Time:** 2026-10-15 19:50 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Activity feeds — SMS filter pills (All / Flagged / Known), call volume stats + filters, keyword watchlist chip cloud, reciprocal ledger footer linking to audit.

**Files:**
- `lib/app/modules/device_detail/views/activity_feed_tab.dart`

**Impact:** UI only. Filters derived from event payloads; no new API. Avatar photos still skipped (no photo URLs).

### Changed — 2026-10-15

**Time:** 2026-10-15 19:45 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Phase 1 Stitch pixel-compare pass: Messages/Calls/SMS activity feeds, pairing code/QR/expired/success, soft-disconnect confirm with purge, Device Care tab, Home skeleton + Family Circle switcher + dark theme toggle, offline/connection error, Usage + Notification permission setup.

**Files:**
- `lib/app/modules/device_detail/views/activity_feed_tab.dart`, `device_care_tab.dart`, `device_detail_view.dart`, `controllers/device_detail_controller.dart`
- `lib/app/modules/pairing/views/pairing_initiate_view.dart`, `pairing_complete_view.dart`, `pairing_success_view.dart`, `permission_setup_view.dart`
- `lib/app/modules/dashboard/views/home_tab.dart`, `account_tab.dart`
- `lib/app/core/widgets/confirm_device_action_sheet.dart`, `family_circle_switcher.dart`, `app_states.dart`
- `lib/app/core/theme/theme_mode_controller.dart`, `app.dart`, `app_providers.dart`, `routes/app_routes.dart`

**Impact:** UI/UX only. Existing `/api/v1/` + Provider/Navigator/`one_request` unchanged. No multi-tenant switch API (Family Circle shows active workspace only).

### Changed — 2026-10-15

**Time:** 2026-10-15 19:16 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Continued Consent Horizon rebuild: home dashboard copy/stats, pairing waiting + consent confirm, account security cards, device overview/manage actions, event detail, audit transparency ledger tiles; `one_request` 3.1.0 confirmed.

**Files:**
- `spy_love/lib/app/modules/dashboard/views/home_tab.dart` — mutual consent hero + Stitch stats
- `spy_love/lib/app/modules/auth/views/account_security_card.dart` — link Google / set password chrome
- `spy_love/lib/app/modules/pairing/views/pairing_initiate_view.dart`, `pairing_complete_view.dart`
- `spy_love/lib/app/modules/device_detail/views/device_detail_view.dart`, `event_detail_view.dart`
- `spy_love/lib/app/modules/audit/views/audit_log_view.dart` — TransparencyLedgerTile rows
- `spy_love/lib/app/core/widgets/consent_row.dart`, `subscription_plans_view.dart`

**Impact:** UI polish only. Existing `/api/v1/` endpoints unchanged. HTTP remains `one_request` 3.1.0.

### Changed — 2026-10-15

**Time:** 2026-10-15 19:11 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Rebuilt Flutter UI onto Stitch Consent Horizon: theme tokens (light/dark), responsive shell, shared widgets, and screen polish wired to existing `/api/v1/` + `one_request` 3.1.0.

**Files:**
- `spy_love/lib/app/core/theme/app_colors.dart`, `app_tokens.dart`, `app_theme.dart` — Consent Horizon palette, spacing, radii, breakpoints
- `spy_love/lib/app/core/config/app_config.dart` — primary/status colors from AppColors
- `spy_love/lib/app/core/widgets/` — buttons, cards, status chips, states, responsive scaffold, transparency ledger tile, app page
- `spy_love/lib/app/app.dart` — ScaledTextScope
- `spy_love/lib/app/modules/auth/views/auth_view.dart` — Stitch login/onboarding
- `spy_love/lib/app/modules/dashboard/views/` — home, devices, account, dashboard breakpoints
- `spy_love/lib/app/modules/pairing/views/` — hub, initiate, complete copy/layout
- `spy_love/lib/app/modules/subscription/views/subscription_plans_view.dart`
- `spy_love/lib/app/modules/audit/views/audit_log_view.dart`
- `spy_love/lib/app/modules/device_detail/views/device_detail_view.dart`
- `spy_love/pubspec.yaml` — `one_request` ^3.1.0 (pub.dev latest)

**Impact:** UI/theme only. Stack unchanged (Provider, Navigator, one_request). No new API endpoints.

### Changed — 2026-10-15

**Time:** 2026-10-15 19:05 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** low
**Issue:** n/a

**Summary:** Confirmed pub.dev latest `one_request` is 3.1.0; kept `^3.1.0`, ran `flutter pub get` (lock already 3.1.0); no breaking API fixes needed; app networking stays on OneRequest only.

**Files:**
- `spy_love/pubspec.yaml` — note latest published 3.1.0; constraint unchanged
- `spy_love/pubspec.lock` — resolved `one_request` 3.1.0 via pub get

**Impact:** none — already on latest; no other HTTP clients added.

### Added — 2026-10-15

**Time:** 2026-10-15 16:28 (UTC+6)
**Author:** Grok Bot
**Model:** Grok Bot
**Mode:** high
**Issue:** n/a

**Summary:** Implemented missing event collectors (battery, network, app_usage, device_info) via MonitoringPlugin MethodChannel and MonitoringService periodic sync; Usage Access settings opener; default pairing scopes include the new ones.

**Files:**
- `spy_love/lib/app/core/monitoring/collectors_bridge.dart` — new bridge
- `spy_love/lib/app/core/monitoring/monitoring_service.dart` — sync battery/network/device_info/app_usage
- `spy_love/android/app/src/main/kotlin/org/hmg/spy_love/MonitoringPlugin.kt` — native collectors
- `spy_love/android/app/src/main/AndroidManifest.xml` — ACCESS_NETWORK_STATE, PACKAGE_USAGE_STATS
- `spy_love/lib/app/modules/pairing/controllers/pairing_controller.dart` — default scopes

**Impact:** Linked monitored Android devices upload `battery.status`, `network.status`, `app_usage.snapshot`, `device_info.snapshot` when consent allows (server-side). App usage needs Usage Access granted in settings. No new pubspec deps (connectivity_plus still banned). Backups: `*.bak-collectors`.

### Changed — 2026-09-30

**Time:** 2026-09-30 17:51 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** agent
**Issue:** n/a

**Summary:** Allowed cleartext HTTP in the Android debug build so the emulator can reach the local API.

**Files:**
- `spy_love/android/app/src/debug/AndroidManifest.xml` — `usesCleartextTraffic` for debug only

**Impact:** Debug Android builds can call `http://127.0.0.1:8002`. Release builds are unchanged.

### Changed — 2026-09-30

**Time:** 2026-09-30 16:22 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** agent
**Issue:** n/a

**Summary:** Request chrome and the theme now take brand colors from AppConfig and follow light or dark mode.

**Files:**
- `spy_love/lib/app/core/config/app_config.dart` — theme-aware surface, text, and scrim
- `spy_love/lib/app/core/network/spy_request_chrome.dart` — wait card and offline bar
- `spy_love/lib/app/core/network/one_request_config.dart` — loader colors from AppConfig
- `spy_love/lib/app/core/theme/app_theme.dart` — primary color from AppConfig

**Impact:** Loading and offline UI switch with the system theme.

### Changed — 2026-09-30

**Time:** 2026-09-30 15:58 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** agent
**Issue:** n/a

**Summary:** Replaced one_request EasyLoading toasts with Spy Love chrome: a navy wait card, the app snackbar for errors, and a matching offline bar.

**Files:**
- `spy_love/lib/app/core/network/spy_request_chrome.dart` — wait card and offline bar
- `spy_love/lib/app/core/network/api_service.dart` — app loader and snackbar; package overlays off per call
- `spy_love/lib/app/core/network/one_request_config.dart` — disable EasyLoading; custom connectivity builder
- `spy_love/lib/app/core/network/network_service.dart` — back-online snackbar
- `spy_love/lib/app/app.dart` — overlay above the navigator
- `spy_love/lib/app/app_providers.dart` — request overlay controller

**Impact:** Loading and offline UI. Restart the app to see it; hot reload is not enough for the provider change.

### Fixed — 2026-09-30

**Time:** 2026-09-30 15:52 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** agent
**Issue:** n/a

**Summary:** Replaced the empty Flutter test file so `flutter test` loads a `main` and checks the result type, consent scopes, and API paths.

**Files:**
- `spy_love/test/widget_test.dart` — three contract checks

**Impact:** `flutter test` passes (3 tests).

### Changed — 2026-09-30

**Time:** 2026-09-30 15:38 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** agent
**Issue:** n/a

**Summary:** Upgraded Flutter packages to current compatible releases and moved the app onto one_request 3.1: per-service client, connectivity notices, and a live event socket.

**Files:**
- `spy_love/pubspec.yaml` — `one_request` ^3.1.0; dropped direct `connectivity_plus`
- `spy_love/pubspec.lock` — resolved one_request 3.1.0 plus firebase_core 4.15.0, flutter_secure_storage 11.2.0, geolocator 14.1.1, mobile_scanner 7.4.2
- `spy_love/lib/app/core/network/api_service.dart` — `OneRequest(baseUrl:, headers:)`; absolute JWT refresh URL
- `spy_love/lib/app/core/network/one_request_config.dart` — `setConnectivity` snackbar and websocket reconnect
- `spy_love/lib/app/core/network/network_service.dart` — online flag from `OneRequest.checkConnectivity`
- `spy_love/lib/app/core/network/event_stream_client.dart` — `OneRequest.socket` for device events
- `spy_love/lib/app/modules/device_detail/controllers/device_detail_controller.dart` — refresh on live events
- `spy_love/lib/app/routes/app_routes.dart` — pass token storage into device detail

**Impact:** HTTP client and connectivity. Device detail listens on `ws/v1/events/` while open. `flutter analyze` reports no issues.

### Added — 2026-09-30

**Time:** 2026-09-30 15:02 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Added Flutter Cursor workflow docs so app changes are logged in this folder.

**Files:**
- `spy_love/.cursor/rules/app-workflow.mdc` — conventions and changelog path
- `spy_love/.cursor/workflow/README.md` — module map

**Impact:** none

### Changed — 2026-09-07

**Time:** 2026-09-07 18:28 (UTC+6)
**Author:** Cursor agent
**Model:** Auto
**Mode:** high
**Issue:** n/a

**Summary:** Bumped direct plugins to current releases and moved HTTP onto one_request 3 for every platform, including web. Recorded after the fact; this folder did not exist during that change.

**Files:**
- `spy_love/pubspec.yaml` — one_request 3.0.0; connectivity_plus, firebase_core, flutter_secure_storage, permission_handler, geolocator, flutter_map, latlong2, google_fonts, mobile_scanner, uuid, intl, url_launcher, cupertino_icons; direct dio removed
- `spy_love/lib/app/core/network/api_service.dart` — single client; `OneRequest.setAuth`; map package Either to app Left=success
- `spy_love/lib/app/core/types/either.dart` — local Left=success Either
- `spy_love/lib/app/app.dart` — `OneRequest.wrap()`
- `spy_love/lib/app/core/bootstrap/app_bootstrap.dart` — OneRequest setup on all platforms
- `spy_love/android/app/build.gradle.kts` — `compileSdk` 37

**Impact:** API client. JWT refresh is handled by one_request. Web no longer uses a separate Dio client.
