import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_colors.dart';
import 'package:spy_love/core/theme/app_tokens.dart';

enum AppButtonVariant { primary, secondary, soft, ghost, destructive }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final AppButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = onPressed != null && !loading;

    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AppButtonVariant.primary
                  ? AppColors.white
                  : AppColors.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
      AppButtonVariant.secondary => FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.input,
          foregroundColor: tokens.primaryText,
        ),
        child: child,
      ),
      AppButtonVariant.soft => FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primarySoft,
          foregroundColor: Theme.of(context).colorScheme.primary,
        ),
        child: child,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
      AppButtonVariant.destructive => FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.dangerSoft,
          foregroundColor: tokens.revokeText,
        ),
        child: child,
      ),
    };

    final sized = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.touchMin),
      child: button,
    );
    if (!expand) return sized;
    return SizedBox(width: double.infinity, child: sized);
  }
}
