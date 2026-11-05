import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_share_session.dart';

void main() {
  test('fromPendingResponse reads a bare session object', () {
    final session = ScreenShareSession.fromPendingResponse({
      'id': 'abc',
      'device_id': 'dev-1',
      'status': 'active',
      'ws_url': 'ws/v1/screen/abc/',
      'control_status': 'none',
    });
    expect(session, isNotNull);
    expect(session!.id, 'abc');
    expect(session.isOpen, isTrue);
    expect(session.controlStatus, 'none');
  });

  test('fromPendingResponse reads the results list the backend actually returns', () {
    final session = ScreenShareSession.fromPendingResponse({
      'results': [
        {
          'id': 'sess-9',
          'device_id': 'dev-2',
          'status': 'active',
          'ws_url': 'ws/v1/screen/sess-9/',
          'control_status': 'requested',
          'requested_by_email': 'monitor@example.com',
        },
      ],
    });
    expect(session, isNotNull);
    expect(session!.id, 'sess-9');
    expect(session.controlRequested, isTrue);
    expect(session.requestedByEmail, 'monitor@example.com');
  });

  test('fromPendingResponse returns null for an empty results list', () {
    expect(ScreenShareSession.fromPendingResponse({'results': []}), isNull);
    expect(ScreenShareSession.fromPendingResponse({}), isNull);
  });

  test('control helpers follow the grant states', () {
    final approved = ScreenShareSession.fromJson({
      'id': '1',
      'device_id': 'd',
      'status': 'active',
      'ws_url': 'ws/v1/screen/1/',
      'control_status': 'approved',
    });
    expect(approved.controlApproved, isTrue);
    expect(approved.copyWith(controlStatus: 'denied').controlDenied, isTrue);
  });
}
