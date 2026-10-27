# Android release APKs

GitHub Actions workflow: [`.github/workflows/release-apk.yml`](../.github/workflows/release-apk.yml).

The workflow builds four signed release APKs and uploads them to a GitHub Release:

| File | Contents |
|---|---|
| `SpyLove-<version>-arm64-v8a.apk` | 64-bit ARM |
| `SpyLove-<version>-armeabi-v7a.apk` | 32-bit ARM |
| `SpyLove-<version>-x86_64.apk` | 64-bit x86 |
| `SpyLove-<version>-universal.apk` | All three ABIs |

This project does not set `abiFilters`. Flutter's release APK targets are `android-arm`, `android-arm64`, and `android-x64`. 32-bit x86 is not built.

`<version>` is the git tag with the leading `v` removed (`v1.0.0` → `1.0.0`). The APK `versionName` / `versionCode` still come from `pubspec.yaml` (`1.0.0+1` → name `1.0.0`, code `1`). Bump `pubspec.yaml` before you tag so those match.

## GitHub Release page

The workflow titles the release `Spy Love <version> — Consent Horizon`. Before publish it writes a fixed description (intro, what is included, the APK table, install steps, and notes for Android 7.0 / API 24, https://spy.way2points.com, and Firebase) and passes that file as `body_path`. Commits since the previous tag are appended under **Changes since last release**. APK filenames stay the same.

## Cut a release

1. Bump `version:` in `pubspec.yaml` and commit that on `master`.
2. Tag the same commit and push the tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Any tag matching `v*` starts the workflow. You can also run it by hand from the Actions tab (`workflow_dispatch`). The optional `tag` input (for example `v1.0.0`) names the GitHub Release. If you leave it empty, the tag is `v` plus the `pubspec.yaml` version before `+`.

## Required GitHub secrets

Add these under **Settings → Secrets and variables → Actions → Secrets**. Do not commit the keystore or `android/key.properties`.

| Secret | Maps to `android/key.properties` | What to put |
|---|---|---|
| `KEYSTORE_BASE64` | `storeFile` (the file itself) | Base64 of the `.jks` / `.keystore` file |
| `KEYSTORE_PASSWORD` | `storePassword` | Keystore password |
| `KEY_ALIAS` | `keyAlias` | Key alias inside the keystore |
| `KEY_PASSWORD` | `keyPassword` | Key password |

`android/app/build.gradle.kts` reads those four properties from `android/key.properties`. `storeFile` is resolved relative to the `android/` directory. The workflow writes `android/keystore/release.jks` and points `storeFile` at `keystore/release.jks`.

Create `KEYSTORE_BASE64` from the backup keystore (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("D:\Spy_LOve_keystore_backup\your-keystore.jks")) | Set-Clipboard
```

Or on a machine with OpenSSL / Git Bash:

```bash
base64 -w 0 your-keystore.jks
```

Paste the single line into the secret. PKCS12 keystores need `KEYSTORE_PASSWORD` and `KEY_PASSWORD` to be the same value. Passwords must not contain newlines.

Local debug builds do not need these secrets. If `android/key.properties` is missing, debug uses the default debug keystore. A release build on GitHub Actions fails when the secrets are missing, so a debug-signed APK is not published. When `key.properties` is present locally, debug and release both use that keystore so the Google Sign-In certificate stays the same.

## API host baked into the APK

The workflow passes:

```text
--dart-define=API_BASE_URL=https://spy.way2points.com/api/v1
--dart-define=WS_BASE_URL=wss://spy.way2points.com/ws/v1/events/
```

Override either URL with a repository **variable** of the same name (`API_BASE_URL`, `WS_BASE_URL`). Those are not secrets. The same production URLs are the defaults in `lib/core/config/app_config.dart`, so a local build without `--dart-define` talks to `spy.way2points.com`. A define that points the API host at ngrok still sends `ngrok-skip-browser-warning`; production traffic does not.

## Toolchain

- Java Temurin 17
- Flutter 3.47.8 (Dart 3.13.7), which satisfies `pubspec.yaml` `sdk: ^3.12.1`
- `compileSdk` 37 with `compileSdkMinor` 0, which resolves the published SDK directory `platforms/android-37.0` (`permission_handler_android` 14 requires API 37). `targetSdk` stays on the Flutter default (36)
- NDK `28.2.13676358` (`flutter.ndkVersion` on Flutter 3.47.8)
- R8 minify and resource shrinking stay off, matching `android/app/build.gradle.kts`
