import 'package:spy_love/app/core/constants/api_constants.dart';
import 'package:spy_love/app/core/network/api_service.dart';
import 'package:spy_love/app/core/network/http_method.dart';
import 'package:spy_love/app/core/types/either.dart';
import 'package:spy_love/app/modules/device_detail/models/device_event_model.dart';

class EventRepository {
  EventRepository(this._api);

  final ApiService _api;

  Future<Either<List<DeviceEventModel>, String>> listEvents({
    required String deviceId,
    String? eventPrefix,
    int page = 1,
    int pageSize = 20,
    bool loader = true,
  }) async {
    final query = <String, dynamic>{
      'device_id': deviceId,
      'page': page,
      'page_size': pageSize,
    };
    if (eventPrefix != null && eventPrefix.isNotEmpty) {
      query['event_prefix'] = eventPrefix;
    }

    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.events,
      method: HttpMethod.get,
      queryParameters: query,
      loader: loader,
    );

    if (result.isLeft) {
      final data = result.left;
      final results = data['results'] as List<dynamic>? ?? const [];
      final events = results
          .map((e) => DeviceEventModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return Left(events);
    }
    return Right(result.right);
  }

  Future<Either<List<DeviceEventModel>, String>> listAllEvents({
    required String deviceId,
    String? eventPrefix,
    int maxPages = 5,
    int pageSize = 100,
  }) async {
    final all = <DeviceEventModel>[];
    for (var page = 1; page <= maxPages; page++) {
      final result = await listEvents(
        deviceId: deviceId,
        eventPrefix: eventPrefix,
        page: page,
        pageSize: pageSize,
        loader: page == 1,
      );
      if (result.isRight) return Right(result.right);

      final batch = result.left;
      all.addAll(batch);
      if (batch.length < pageSize) break;
    }
    return Left(all);
  }

  /// Returns the ingest payload on success (may include `paused` / `paused_until`).
  Future<Either<Map<String, dynamic>, String>> uploadBatch({
    required String deviceId,
    required List<Map<String, dynamic>> events,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.eventsBatch,
      method: HttpMethod.post,
      body: {
        'device_id': deviceId,
        'events': events,
      },
      loader: false,
      resultOverlay: false,
    );

    if (result.isLeft) return Left(result.left);
    return Right(result.right);
  }
}
