import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/theme/app_colors.dart';
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

/// Branded Consent Horizon blocking overlay for user-initiated requests only.
class SpyRequestOverlay extends StatelessWidget {
  const SpyRequestOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final visible = context.watch<RequestOverlayController>().visible;
    if (!visible) return const SizedBox.shrink();

    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(dismissible: false, color: AppConfig.scrim(context)),
          const Center(child: _BrandedWaitCard()),
        ],
      ),
    );
  }
}

class _BrandedWaitCard extends StatelessWidget {
  const _BrandedWaitCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 168, maxWidth: 220),
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: tokens.border),
          boxShadow: tokens.floatingShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.skyTint, AppColors.primary],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: AppColors.primary,
                backgroundColor: tokens.primarySoft,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              AppConfig.appName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: tokens.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please wait…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.secondaryText,
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
              const Icon(
                Icons.wifi_off,
                color: AppConfig.warningColor,
                size: 20,
              ),
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
