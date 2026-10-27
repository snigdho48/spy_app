# Spy Love Flutter workflow

Consent-based monitoring client. Talks to the Django API under `backend/`.

## Map

| Area | Path |
|------|------|
| Entry / bootstrap | `lib/main.dart`, `lib/app/core/bootstrap/app_bootstrap.dart` |
| Composition | `lib/app/app.dart`, `lib/app/app_providers.dart` |
| Routes | `lib/app/routes/app_routes.dart` |
| HTTP | `lib/app/core/network/api_service.dart`, `one_request_config.dart` |
| Results | `lib/app/core/types/either.dart` — Left success, Right error |
| API paths | `lib/app/core/constants/api_constants.dart` |
| Tokens | `lib/app/core/storage/token_storage.dart` |
| Features | `lib/app/modules/{auth,dashboard,pairing,device_detail,subscription,audit}/` |
| Theme | `lib/app/core/theme/` |

## HTTP

`one_request` 3.1 on every platform. `OneRequest(baseUrl:)` is the API client. `OneRequest.setAuth` attaches the bearer token and refreshes on 401 with an absolute refresh URL. Connectivity notices use `OneRequest.setConnectivity`. Live device events use `OneRequest.socket`. Repositories keep using app `Either` (Left = data). Do not add `dio`, `dart_either`, `flutter_easyloading`, `connectivity_plus`, or `web_socket_channel` directly.

## Checks

```bash
flutter analyze
```

Android compile SDK is 37.

## Changelog

Append every meaningful change to `spy_love/.cursor/workflow/CHANGELOG.md` (see the project rule).
