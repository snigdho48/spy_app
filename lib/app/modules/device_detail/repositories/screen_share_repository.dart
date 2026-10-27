import 'package:spy_love/app/core/constants/api_constants.dart';
import 'package:spy_love/app/core/network/api_service.dart';
import 'package:spy_love/app/core/network/http_method.dart';
import 'package:spy_love/app/core/types/either.dart';
import 'package:spy_love/app/modules/device_detail/models/screen_share_session.dart';

/// REST client for consent-scoped live screen-share sessions.
///
/// Mirrors the backend contract in `apps.devices.presentation`. Every call
/// is gated server-side by the `screen` consent scope + sharing-pause state;
/// this client only moves the session through its lifecycle and never carries
/// frame data (frames use [ScreenStreamClient]).
class ScreenShareRepository {
  ScreenShareRepository(this._api);

  final ApiService _api;

  /// Monitor requests a live view of [deviceId]. 201 -> session (requested).
  Future<Either<ScreenShareSession, String>> requestSession(
    String deviceId,
  ) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.deviceScreenRequest(deviceId),
      method: HttpMethod.post,
    );
    if (result.isLeft) {
      return Left(ScreenShareSession.fromJson(result.left));
    }
    return Right(result.right);
  }

  /// Monitored owner polls for a pending/active session on their own device.
  /// Returns `Left(null)` when there is nothing to act on.
  Future<Either<ScreenShareSession?, String>> pendingForOwner(
    String deviceId, {
    bool loader = false,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.deviceScreenPending(deviceId),
      method: HttpMethod.get,
      loader: loader,
      resultOverlay: false,
    );
    if (result.isLeft) {
      final data = result.left;
      if (data.isEmpty || data['id'] == null) return const Left(null);
      return Left(ScreenShareSession.fromJson(data));
    }
    return Right(result.right);
  }

  /// Monitored owner accepts and starts sharing (after the OS grant).
  Future<Either<ScreenShareSession, String>> startSession(
    String sessionId, {
    bool loader = false,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.screenShareStart(sessionId),
      method: HttpMethod.post,
      loader: loader,
    );
    if (result.isLeft) {
      return Left(ScreenShareSession.fromJson(result.left));
    }
    return Right(result.right);
  }

  /// Monitored owner declines the request.
  Future<Either<ScreenShareSession, String>> denySession(
    String sessionId,
  ) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.screenShareDeny(sessionId),
      method: HttpMethod.post,
    );
    if (result.isLeft) {
      return Left(ScreenShareSession.fromJson(result.left));
    }
    return Right(result.right);
  }

  /// Either side ends the session. Idempotent server-side.
  Future<Either<ScreenShareSession, String>> endSession(
    String sessionId, {
    String? reason,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.screenShareEnd(sessionId),
      method: HttpMethod.post,
      body: reason != null ? {'reason': reason} : null,
      resultOverlay: false,
    );
    if (result.isLeft) {
      return Left(ScreenShareSession.fromJson(result.left));
    }
    return Right(result.right);
  }

  Future<Either<ScreenShareSession, String>> status(String sessionId) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.screenShareStatus(sessionId),
      method: HttpMethod.get,
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) {
      return Left(ScreenShareSession.fromJson(result.left));
    }
    return Right(result.right);
  }
}
