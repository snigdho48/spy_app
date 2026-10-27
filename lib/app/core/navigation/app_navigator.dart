import 'package:flutter/material.dart';

abstract final class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static BuildContext? get context => key.currentContext;

  static Future<T?> toNamed<T extends Object?>(String name, {Object? arguments}) {
    return key.currentState!.pushNamed<T>(name, arguments: arguments);
  }

  static Future<T?> off<T extends Object?>(Widget page) {
    return key.currentState!.pushReplacement(
      MaterialPageRoute<T>(builder: (_) => page),
    );
  }

  static void pop<T extends Object?>([T? result]) {
    key.currentState?.pop(result);
  }

  static void popUntilHome() {
    key.currentState?.popUntil((route) => route.isFirst);
  }

  static void snackbar(
    String title,
    String message, {
    IconData? icon,
    SnackBarAction? action,
  }) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message.isEmpty ? title : '$title\n$message',
              ),
            ),
          ],
        ),
        action: action,
      ),
    );
  }
}
