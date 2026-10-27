class ApiConstants {
  static const authRegister = '/auth/register/';
  static const authLogin = '/auth/login/';
  static const authRefresh = '/auth/token/refresh/';
  static const authLogout = '/auth/logout/';
  static const authMe = '/auth/me/';
  static const authGoogle = '/auth/google/';
  static const authLinkGoogle = '/auth/link/google/';
  static const authSetPassword = '/auth/link/password/';

  static const subscriptionPlans = '/subscriptions/plans/';
  static const subscriptionCurrent = '/subscriptions/current/';
  static const subscriptionSubscribe = '/subscriptions/subscribe/';
  static const workspaceCreate = '/subscriptions/workspaces/';

  /// Returned as [Either.right] when Google sign-up needs an organization name.
  static const tenantRequiredError = 'tenant_required';

  static const devices = '/devices/';
  static const devicesOwned = '/devices/owned/';
  static String deviceOwnedStatus(String id) => '/devices/owned/$id/status/';
  static String deviceOwnedPause(String id) => '/devices/owned/$id/pause/';
  static String deviceOwnedResume(String id) => '/devices/owned/$id/resume/';
  static String deviceDetail(String id) => '/devices/$id/';
  static String deviceDisconnect(String id) => '/devices/$id/disconnect/';
  static const devicesPairInitiate = '/devices/pair/initiate/';
  static const devicesPairComplete = '/devices/pair/complete/';
  static const safeZones = '/devices/safe-zones/';
  static String safeZoneDetail(String id) => '/devices/safe-zones/$id/';
  static const keywords = '/devices/keywords/';
  static String keywordDetail(String id) => '/devices/keywords/$id/';

  // --- Consent-scoped live screen sharing ---
  /// Monitor requests a live screen view of a device (POST).
  static String deviceScreenRequest(String deviceId) =>
      '/devices/$deviceId/screen/request/';

  /// Monitored owner polls for a pending/active request on their own device.
  static String deviceScreenPending(String deviceId) =>
      '/devices/owned/$deviceId/screen/pending/';

  /// Monitored owner accepts and starts sharing (POST).
  static String screenShareStart(String sessionId) =>
      '/devices/screen/$sessionId/start/';

  /// Monitored owner declines a request (POST).
  static String screenShareDeny(String sessionId) =>
      '/devices/screen/$sessionId/deny/';

  /// Either side ends a session (POST).
  static String screenShareEnd(String sessionId) =>
      '/devices/screen/$sessionId/end/';

  /// Session status (GET).
  static String screenShareStatus(String sessionId) =>
      '/devices/screen/$sessionId/';

  static const events = '/events/';
  static const eventsBatch = '/events/batch/';
  static const eventsContactsLatest = '/events/contacts/latest/';
  static const eventsAppInventoryLatest = '/events/app-inventory/latest/';

  static const audit = '/audit/';
}
