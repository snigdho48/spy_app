import 'dart:io';

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
    expect(AppConfig.defaultHeaders, {'Content-Type': 'application/json'});
    expect(
      AppConfig.screenWsUrl('ws/v1/screen/abc/'),
      'wss://spy.way2points.com/ws/v1/screen/abc/',
    );
    expect(
      AppConfig.screenWsUrl('wss://stale.example/ws/v1/screen/abc/'),
      'wss://spy.way2points.com/ws/v1/screen/abc/',
    );
    expect(AppConfig.isForeignStoredHost('https://stale.example/api/v1'), isTrue);
    expect(AppConfig.isForeignStoredHost(AppConfig.apiBaseUrl), isFalse);
    expect(AppConfig.isForeignStoredHost(AppConfig.wsBaseUrl), isFalse);
    expect(AppConfig.isForeignStoredHost('system'), isFalse);
    expect(
      AppConfig.isForeignStoredHost('{"url":"https://stale.example/api/v1"}'),
      isFalse,
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

  test('github release description does not publish the API host', () {
    final workflow = File('.github/workflows/release-apk.yml').readAsStringSync();
    const marker = 'cat > release-notes.md << EOF\n';
    final start = workflow.indexOf(marker);
    expect(start, greaterThanOrEqualTo(0));
    final bodyStart = start + marker.length;
    final end = workflow.indexOf('\n          EOF', bodyStart);
    expect(end, greaterThan(bodyStart));
    final body = workflow.substring(bodyStart, end);
    expect(body.contains('way2points'), isFalse);
    expect(body.contains('https://'), isFalse);
    expect(body.contains('wss://'), isFalse);
    expect(body.contains('API 24'), isTrue);
    expect(body.contains('Firebase'), isTrue);
  });

  test('client paths stay aligned with the API', () {
    expect(ApiConstants.authRefresh, '/auth/token/refresh/');
    expect(ApiConstants.eventsBatch, '/events/batch/');
    expect(ApiConstants.devicesPairComplete, '/devices/pair/complete/');
    expect(ApiConstants.safeZones, '/devices/safe-zones/');
    expect(ApiConstants.keywords, '/devices/keywords/');
  });
}
