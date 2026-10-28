import 'package:spy_love/core/constants/api_constants.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/http_method.dart';
import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/features/alerts/models/alert_model.dart';

/// One page of alerts plus the paginator cursor the backend returns.
class AlertPage {
  const AlertPage({
    required this.alerts,
    required this.count,
    required this.hasNext,
  });

  final List<AlertModel> alerts;
  final int count;
  final bool hasNext;
}

class AlertRepository {
  AlertRepository(this._api);

  final ApiService _api;

  /// GET /alerts/ — paginated. [loader] stays false for background polling so
  /// the global branded overlay never blocks the UI (see [ApiService.send]).
  Future<Either<AlertPage, String>> list({
    String? deviceId,
    AlertType? type,
    bool unreadOnly = false,
    int page = 1,
    int pageSize = 25,
    bool loader = false,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      'device_id': ?deviceId,
      if (type != null && type != AlertType.other) 'type': type.id,
      if (unreadOnly) 'unread': 'true',
    };

    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.alerts,
      method: HttpMethod.get,
      queryParameters: query,
      loader: loader,
      resultOverlay: false,
    );

    if (result.isLeft) {
      final data = result.left;
      final results = data['results'] as List<dynamic>? ?? const [];
      final alerts = results
          .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final count = (data['count'] as num?)?.toInt() ?? alerts.length;
      final hasNext = data['next'] != null;
      return Left(AlertPage(alerts: alerts, count: count, hasNext: hasNext));
    }
    return Right(result.right);
  }

  /// Convenience: unread count via a minimal page fetch.
  Future<int> unreadCount({String? deviceId}) async {
    final result = await list(
      deviceId: deviceId,
      unreadOnly: true,
      pageSize: 1,
      loader: false,
    );
    return result.fold((page) => page.count, (_) => 0);
  }

  Future<Either<void, String>> markRead(String id) async {
    final result = await _api.send<void>(
      url: ApiConstants.alertRead(id),
      method: HttpMethod.post,
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) return const Left(null);
    return Right(result.right);
  }

  Future<Either<void, String>> markAllRead({String? deviceId}) async {
    final result = await _api.send<void>(
      url: ApiConstants.alertsReadAll,
      method: HttpMethod.post,
      queryParameters: {'device_id': ?deviceId},
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) return const Left(null);
    return Right(result.right);
  }

  /// DELETE /alerts/{id}/ — monitor/admin only; VIEWER gets 403.
  Future<Either<void, String>> delete(String id) async {
    final result = await _api.send<void>(
      url: ApiConstants.alertDetail(id),
      method: HttpMethod.delete,
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) return const Left(null);
    return Right(result.right);
  }

  /// POST /alerts/push-tokens/ — register an FCM token. Returns the server id.
  Future<Either<String, String>> registerPushToken({
    required String token,
    required String platform,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.pushTokens,
      method: HttpMethod.post,
      body: {'token': token, 'platform': platform},
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) return Left(result.left['id'].toString());
    return Right(result.right);
  }

  /// DELETE /alerts/push-tokens/{id}/ — unregister on logout.
  Future<Either<void, String>> deletePushToken(String id) async {
    final result = await _api.send<void>(
      url: ApiConstants.pushTokenDetail(id),
      method: HttpMethod.delete,
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) return const Left(null);
    return Right(result.right);
  }
}
