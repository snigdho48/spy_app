import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/theme/app_tokens.dart';

/// Tracks in-flight requests so the app can show its own loader instead of EasyLoading.
class RequestOverlayController extends ChangeNotifier {
  int _pending = 0;

  bool get visible => _pending > 0;

  void begin() {
    _pending++;
    notifyListeners();
  }

  void end() {
    if (_pending == 0) return;
    _pending--;
    notifyListeners();
  }
}

/// Navy card and primary spinner. Sits above the page while a request is running.
class SpyRequestOverlay extends StatelessWidget {
  const SpyRequestOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final visible = context.watch<RequestOverlayController>().visible;
    if (!visible) return const SizedBox.shrink();

    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: AppConfig.scrim(context),
          ),
          const Center(child: _WaitCard()),
        ],
      ),
    );
  }
}

class _WaitCard extends StatelessWidget {
  const _WaitCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppConfig.surface(context),
      elevation: 0,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppConfig.primaryColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Please wait',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppConfig.onSurface(context),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Persistent offline bar in the same floating style as [SnackBarTheme].
class SpyOfflineBar extends StatelessWidget {
  const SpyOfflineBar({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Material(
        color: AppConfig.surface(context),
        elevation: 0,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: AppConfig.warningColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Check your internet and try again.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppConfig.onSurface(context),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
