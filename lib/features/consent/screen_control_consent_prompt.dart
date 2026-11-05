import 'package:flutter/material.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';

/// Explicit Allow/Deny gate shown on the PAIRED device before remote input
/// (taps, swipes, Back/Home/Recents) is allowed. Never auto-accepts.
///
/// Screen *view* stays scope-based after enrollment. Control is a separate
/// privilege and must be approved for each request.
Future<bool> showScreenControlConsentPrompt({
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
      icon: Icon(
        Icons.touch_app,
        color: Theme.of(ctx).colorScheme.primary,
        size: 32,
      ),
      title: const Text('Allow remote control?'),
      content: Text(
        '$requester wants to control $device\'s screen — taps, swipes, and '
        'Back / Home / Recents — while the screen is already being viewed.\n\n'
        'This does not start automatically. If you allow, you can stop control '
        'anytime. Viewing the screen is separate and is not changed by Deny.',
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

/// Shown after Allow when the Accessibility service needed to inject
/// gestures is not enabled yet. Returns true if the user chose to open
/// Settings. Never treats this as a silent control approval.
Future<bool> showEnableAccessibilityForControlPrompt() async {
  final context = AppNavigator.context;
  if (context == null) return false;

  final open = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.accessibility_new, size: 32),
      title: const Text('Enable Accessibility to allow control'),
      content: const Text(
        'Remote taps and navigation need the Spy Love Accessibility service '
        'turned on. This is used only after you approve each control request — '
        'it does not record keystrokes or passwords.\n\n'
        'Open Settings → Accessibility to enable Spy Love, then return here.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Open settings'),
        ),
      ],
    ),
  );
  return open ?? false;
}
