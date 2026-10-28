import 'package:permission_handler/permission_handler.dart';

/// Maps backend consent scopes to OS runtime permissions.
class AppPermission {
  const AppPermission({
    required this.scope,
    required this.permission,
    required this.title,
    required this.description,
  });

  final String scope;
  final Permission permission;
  final String title;
  final String description;

  static const List<AppPermission> monitoring = [
    AppPermission(
      scope: 'location',
      permission: Permission.locationWhenInUse,
      title: 'Location',
      description: 'Required to share location updates when you grant consent.',
    ),
    AppPermission(
      scope: 'notifications',
      permission: Permission.notification,
      title: 'Notifications',
      description: 'Alerts you about monitoring status and consent changes.',
    ),
    AppPermission(
      scope: 'pairing',
      permission: Permission.camera,
      title: 'Camera',
      description: 'Scan QR codes to pair this device with your account.',
    ),
  ];

  static const List<AppPermission> dataCollection = [
    AppPermission(
      scope: 'call_log',
      permission: Permission.phone,
      title: 'Phone & call log',
      description: 'Read call history (numbers, duration, type).',
    ),
    AppPermission(
      scope: 'sms',
      permission: Permission.sms,
      title: 'SMS',
      description: 'Read text message history on this device.',
    ),
    AppPermission(
      scope: 'sim',
      permission: Permission.phone,
      title: 'SIM & phone number',
      description:
          'Read active SIM numbers and detect SIM insert/remove events.',
    ),
  ];
}
