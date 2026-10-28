import 'package:spy_love/core/constants/api_constants.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/http_method.dart';
import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/features/devices/models/safe_zone_model.dart';

class SafeZoneRepository {
  SafeZoneRepository(this._api);

  final ApiService _api;

  /// GET /devices/safe-zones/ — optionally scoped to a device. Background
  /// fetches keep loader:false so the global overlay never trips.
  Future<Either<List<SafeZoneModel>, String>> list({String? deviceId}) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.safeZones,
      method: HttpMethod.get,
      queryParameters: {'device_id': ?deviceId},
      loader: false,
      resultOverlay: false,
    );

    if (result.isLeft) {
      final results = result.left['results'] as List<dynamic>? ?? const [];
      return Left(
        results
            .map((e) => SafeZoneModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
    return Right(result.right);
  }

  Future<Either<SafeZoneModel, String>> create({
    required String name,
    required double lat,
    required double lng,
    int radiusM = 100,
    String address = '',
    String? deviceId,
    bool enabled = true,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.safeZones,
      method: HttpMethod.post,
      body: {
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius_m': radiusM,
        'enabled': enabled,
        if (address.isNotEmpty) 'address': address,
        'device_id': ?deviceId,
      },
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) {
      return Left(SafeZoneModel.fromJson(result.left));
    }
    return Right(result.right);
  }

  /// PATCH /devices/safe-zones/{id}/ — partial update. Any provided field is
  /// sent; omitted fields are left unchanged server-side.
  Future<Either<SafeZoneModel, String>> update({
    required String id,
    String? name,
    double? lat,
    double? lng,
    int? radiusM,
    String? address,
    bool? enabled,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.safeZoneDetail(id),
      method: HttpMethod.patch,
      body: {
        'name': ?name,
        'lat': ?lat,
        'lng': ?lng,
        'radius_m': ?radiusM,
        'address': ?address,
        'enabled': ?enabled,
      },
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) {
      return Left(SafeZoneModel.fromJson(result.left));
    }
    return Right(result.right);
  }

  Future<Either<void, String>> delete(String id) async {
    final result = await _api.send<void>(
      url: ApiConstants.safeZoneDetail(id),
      method: HttpMethod.delete,
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) return const Left(null);
    return Right(result.right);
  }
}
