import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/app/core/constants/api_constants.dart';
import 'package:spy_love/app/core/types/either.dart';
import 'package:spy_love/app/modules/pairing/models/consent_scope.dart';

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

  test('client paths stay aligned with the API', () {
    expect(ApiConstants.authRefresh, '/auth/token/refresh/');
    expect(ApiConstants.eventsBatch, '/events/batch/');
    expect(ApiConstants.devicesPairComplete, '/devices/pair/complete/');
    expect(ApiConstants.safeZones, '/devices/safe-zones/');
    expect(ApiConstants.keywords, '/devices/keywords/');
  });
}
