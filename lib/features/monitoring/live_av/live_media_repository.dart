import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/http_method.dart';
import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/features/monitoring/live_av/live_media_session.dart';

class LiveMediaRepository {
  LiveMediaRepository(this._api);

  final ApiService _api;

  Future<Either<LiveMediaSession, String>> requestSession(
    String deviceId, {
    required String mediaKind,
    String cameraFacing = 'back',
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: '/devices/$deviceId/media/request/',
      method: HttpMethod.post,
      body: {'media_kind': mediaKind, 'camera_facing': cameraFacing},
    );
    if (result.isLeft) {
      return Left(LiveMediaSession.fromJson(result.left));
    }
    return Right(result.right);
  }

  Future<Either<List<LiveMediaSession>, String>> pendingForOwner(
    String deviceId,
  ) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: '/devices/owned/$deviceId/media/pending/',
      method: HttpMethod.get,
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) {
      final raw = result.left['results'];
      final list = <LiveMediaSession>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            list.add(
              LiveMediaSession.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      return Left(list);
    }
    return Right(result.right);
  }

  Future<Either<LiveMediaSession, String>> startSession(
    String sessionId,
  ) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: '/devices/media/$sessionId/start/',
      method: HttpMethod.post,
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) {
      return Left(LiveMediaSession.fromJson(result.left));
    }
    return Right(result.right);
  }

  Future<Either<LiveMediaSession, String>> setFacing(
    String sessionId,
    String facing,
  ) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: '/devices/media/$sessionId/facing/',
      method: HttpMethod.post,
      body: {'facing': facing},
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) {
      return Left(LiveMediaSession.fromJson(result.left));
    }
    return Right(result.right);
  }

  Future<Either<LiveMediaSession, String>> endSession(
    String sessionId, {
    String reason = '',
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: '/devices/media/$sessionId/end/',
      method: HttpMethod.post,
      body: {'reason': reason},
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) {
      return Left(LiveMediaSession.fromJson(result.left));
    }
    return Right(result.right);
  }
}
