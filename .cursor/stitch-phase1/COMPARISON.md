# Stitch vs app visual comparison

**Method:** Stitch MCP PNGs in this folder. Widget goldens at **412×915** and **800×1280**, **light + dark**, under `app-captures/` (pass 1) and `app-captures/pass2/` (from `test/stitch_visual_compare_test.dart` and `test/stitch_pass2_visual_test.dart`).

---

## How to check Inter on your phone

Widget goldens often fall back when `fonts.gstatic.com` is blocked in CI/tests. On a real device, Inter loads at runtime via `google_fonts`.

```bash
cd spy_love
flutter pub get
# USB device or emulator with network (needed once to cache Inter):
flutter run
# Optional release-like check:
flutter run --release
```

- First launch needs **internet** so Inter can download and cache.
- After cache, offline runs still use Inter.
- Hot reload does not re-fetch fonts; full restart if type looks wrong.
- Do **not** open `.env` / keystores for this check.

Regenerate goldens (layout only; Inter may still warn in tests):

```bash
cd spy_love
flutter test test/stitch_pass2_visual_test.dart --update-goldens
```

---

## Pass 1 — fixed

| Area | Change |
|---|---|
| Hero copy density | Uppercase ledger label, tighter line heights |
| Family Circle progress | Thin Mutual Encryption Guard + thicker Circle Slots; soft Manage + gear |
| Metric cards | Corner pills (Live / Healthy / Alert / In Zone) |
| Badges/chips | Denser pills; `Active & Consented` |
| Calls/SMS feed | Section labels, direction/Family chips, italic previews, `#keyword` chips |

## Pass 2 — fixed (this round)

| Screen | Stitch PNG | Change |
|---|---|---|
| Auth | `login-workspace-onboarding.png` | Workspace-first fields, Caregiver email, Secure Password, OR VERIFY WITH, Continue to Workspace Setup |
| Pairing hub | `pairing-entry-hub.png` | CONSENT VERIFICATION HUB, step 1–3 sequence, Option A/B role cards |
| Pairing success | `pairing-complete-*.png` | Existing success chrome goldened |
| Permissions | `permission-prompts.png` / `os-permission-prompts.png` | Existing step chrome (plugin-safe golden shell) |
| Subscriptions | `subscription-plans.png` | Plans list goldened |
| Overview | `device-detail-overview.png` | Battery/Network/Sync metric strip; Device Management soft + destructive actions |
| Map | `device-detail-location-map.png` | Mutual Transparency card; Active Geofence Zones header; Inside badge; Open Directions |
| SIM | `device-detail-sim-security.png` | SIM Security banner + Swap Alerts On |
| Care | `device-detail-diagnostics.png` | Care chrome goldened |
| Audit | `audit-log-list.png` / `mutual-audit-log-ledger.png` | Ledger list goldened |
| Event detail | `audit-event-detail.png` | Event detail goldened |
| Remove confirm | `device-detail-live-confirm-actions.png` | Disconnect dialog goldened |
| Pairing code / waiting | `monitored-phone-pairing-*.png` | Layout shells goldened |

Goldens: **56** files in `test/goldens/pass2/` (14 screens × 2 sizes × 2 themes).

---

## Still cannot fully match (and why)

1. **Stock photos / map tiles** — Stitch uses photography and styled maps; app uses initials/https `photo_url` and OpenStreetMap tiles (no photo proxy).
2. **Full bottom nav on every Stitch frame** — Several Stitch screens embed Home/Devices/Pair/Account; tab bodies and pushed routes omit that chrome.
3. **Manage Circle / workspace switch** — Out of scope; no multi-tenant switch API.
4. **Combined Calls & SMS tab** — App keeps separate Calls / SMS / Messages routes.
5. **Live QR / camera scanner** — Pairing code/waiting goldens use placeholders; real QR needs `PairingController` + device.
6. **Permission_handler in tests** — Real `PermissionSetupView` hits MissingPluginException; golden uses a static shell matching chrome.
7. **Golden font fidelity** — Tests often cannot download Inter; phone `flutter run` with network is the source of truth.
8. **Stitch marketing metrics** — Fake copy (42k families, exact Westwood map art, ledger hash) is design fiction; UI binds API data.
9. **Consent scope confirm / initiate forms** — Controllers + scanner not fully goldened; hub + success + code shells cover the variants that are stable without API.
