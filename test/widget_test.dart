import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/constants/api_constants.dart';
import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/features/consent/models/consent_scope.dart';
import 'package:spy_love/features/devices/models/device_model.dart';

void main() {
  test('success stays on the left of the app result type', () {
    const ok = Left<String, String>('data');
    const err = Right<String, String>('nope');

    expect(ok.isLeft, isTrue);
    expect(ok.fold((value) => value, (_) => 'x'), 'data');
    expect(err.isRight, isTrue);
    expect(err.fold((_) => 'x', (error) => error), 'nope');
  });

  test('consent scopes stay aligned with the API catalog', () {
    expect(
      ConsentScope.all.map((scope) => scope.id).toSet(),
      {
        'call_log',
        'sms',
        'messaging',
        'sim',
        'location',
        'battery',
        'network',
        'app_usage',
        'device_info',
        'notifications',
        'screen',
      },
    );
    expect(ConsentScope.consentVersion, '1.0.0');
  });

  test('production API and websocket hosts are the compiled defaults', () {
    expect(AppConfig.apiBaseUrl, 'https://spy.way2points.com/api/v1');
    expect(AppConfig.wsBaseUrl, 'wss://spy.way2points.com/ws/v1/events/');
    expect(AppConfig.defaultHeaders.containsKey('ngrok-skip-browser-warning'), isFalse);
    expect(AppConfig.defaultHeaders['Content-Type'], 'application/json');
    expect(
      AppConfig.screenWsUrl('ws/v1/screen/abc/'),
      'wss://spy.way2points.com/ws/v1/screen/abc/',
    );
  });

  test('owned device status tolerates a null tenant name', () {
    final status = OwnedDeviceStatus.fromJson({
      'device_id': 'dev-1',
      'device_name': 'Phone',
      'status': 'pending',
      'tenant_name': null,
      'is_linked': false,
    });

    expect(status.tenantName, isEmpty);
    expect(status.isLinked, isFalse);
  });

  test('client paths stay aligned with the API', () {
    expect(ApiConstants.authRefresh, '/auth/token/refresh/');
    expect(ApiConstants.eventsBatch, '/events/batch/');
    expect(ApiConstants.devicesPairComplete, '/devices/pair/complete/');
    expect(ApiConstants.safeZones, '/devices/safe-zones/');
    expect(ApiConstants.keywords, '/devices/keywords/');
  });
}
