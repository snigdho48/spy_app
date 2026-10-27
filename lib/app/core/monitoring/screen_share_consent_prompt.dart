import 'package:flutter/material.dart';
import 'package:spy_love/app/core/navigation/app_navigator.dart';

/// In-app consent gate shown on the MONITORED device before any screen capture
/// begins.
///
/// The device owner must explicitly tap Allow before the OS capture prompt is
/// raised; Deny declines the request server-side. This is a hard requirement of
/// the consent-first design — the server-side enforcement is defence-in-depth,
/// not the only on-device gate. Returns true only on an explicit Allow.
Future<bool> showScreenShareConsentPrompt({
  String? requestedByEmail,
  String? deviceName,
}) async {
  final context = AppNavigator.context;
  if (context == null) return false;

  final requester = (requestedByEmail != null && requestedByEmail.isNotEmpty)
      ? requestedByEmail
      : 'A monitor on your family circle';
  final device = (deviceName != null && deviceName.isNotEmpty)
      ? deviceName
      : 'this device';

  final allowed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.screen_share, color: Colors.red, size: 32),
      title: const Text('Share your screen?'),
      content: Text(
        '$requester is requesting to view $device\'s screen live.\n\n'
        'If you allow, your screen will be shared in real time until you stop '
        'it. A red banner stays at the top of the screen the whole time, and you '
        'can stop sharing from it at any moment.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Deny'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  return allowed ?? false;
}
