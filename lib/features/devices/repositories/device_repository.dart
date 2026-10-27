import 'package:spy_love/core/constants/api_constants.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/http_method.dart';
import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/consent/models/pairing_initiate_result.dart';

class DeviceRepository {
  DeviceRepository(this._api);

  final ApiService _api;

  Future<Either<List<DeviceModel>, String>> listDevices() async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.devices,
      method: HttpMethod.get,
      queryParameters: const {'page_size': 100},
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) {
      final data = result.left;
      final results = data['results'] as List<dynamic>? ?? const [];
      final devices = results
          .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return Left(devices);
    }
    return Right(result.right);
  }

  Future<Either<List<DeviceModel>, String>> listOwnedDevices() async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.devicesOwned,
      method: HttpMethod.get,
      loader: false,
      resultOverlay: false,
    );

    if (result.isLeft) {
      final results = result.left['results'] as List<dynamic>? ?? const [];
      return Left(
        results.map((e) => DeviceModel.fromJson(e as Map<String, dynamic>)).toList(),
      );
    }
    return Right(result.right);
  }

  Future<Either<OwnedDeviceStatus, String>> getOwnedDeviceStatus(String id) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.deviceOwnedStatus(id),
      method: HttpMethod.get,
      loader: false,
      resultOverlay: false,
    );

    if (result.isLeft) {
      return Left(OwnedDeviceStatus.fromJson(result.left));
    }
    return Right(result.right);
  }

  Future<Either<SharingState, String>> pauseOwnedDevice({
    required String id,
    required int durationMinutes,
    String reason = '',
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.deviceOwnedPause(id),
      method: HttpMethod.post,
      body: {
        'duration_minutes': durationMinutes,
        if (reason.isNotEmpty) 'reason': reason,
      },
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) {
      return Left(
        SharingState.fromJson(result.left['sharing'] as Map<String, dynamic>?),
      );
    }
    return Right(result.right);
  }

  Future<Either<SharingState, String>> resumeOwnedDevice(String id) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.deviceOwnedResume(id),
      method: HttpMethod.post,
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) {
      return Left(
        SharingState.fromJson(result.left['sharing'] as Map<String, dynamic>?),
      );
    }
    return Right(result.right);
  }

  Future<Either<Map<String, dynamic>, String>> getDevice(String id) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.deviceDetail(id),
      method: HttpMethod.get,
      loader: false,
    );

    if (result.isLeft) return Left(result.left);
    return Right(result.right);
  }

  Future<Either<DeviceModel, String>> updateDevicePhoto({
    required String id,
    required String photoUrl,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.deviceDetail(id),
      method: HttpMethod.patch,
      body: {'photo_url': photoUrl},
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) {
      return Left(DeviceModel.fromJson(result.left));
    }
    return Right(result.right);
  }

  Future<Either<DeviceModel, String>> disconnectDevice(String id) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.deviceDisconnect(id),
      method: HttpMethod.post,
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) {
      return Left(DeviceModel.fromJson(result.left));
    }
    return Right(result.right);
  }

  Future<Either<void, String>> deleteDevice(String id) async {
    final result = await _api.send<void>(
      url: ApiConstants.deviceDetail(id),
      method: HttpMethod.delete,
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) return const Left(null);
    return Right(result.right);
  }

  Future<Either<PairingInitiateResult, String>> initiatePairing({
    required String deviceName,
    required String platform,
    required String deviceFingerprint,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.devicesPairInitiate,
      method: HttpMethod.post,
      body: {
        'device_name': deviceName,
        'platform': platform,
        'device_fingerprint': deviceFingerprint,
      },
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) {
      return Left(PairingInitiateResult.fromJson(result.left));
    }
    return Right(result.right);
  }

  Future<Either<DeviceModel, String>> completePairing({
    required String pairingCode,
    required List<String> consentScopes,
    String consentVersion = '1.0.0',
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.devicesPairComplete,
      method: HttpMethod.post,
      body: {
        'pairing_code': pairingCode,
        'consent_scopes': consentScopes,
        'consent_version': consentVersion,
      },
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) {
      final device = result.left['device'] as Map<String, dynamic>;
      return Left(DeviceModel.fromJson(device));
    }
    return Right(result.right);
  }
}
