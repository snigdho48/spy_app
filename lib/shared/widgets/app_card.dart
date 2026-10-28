import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.borderColor,
    this.elevated = true,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final bool elevated;

  /// Spoken label for screen readers. When [onTap] is set the card is exposed
  /// as a button.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final decoration = BoxDecoration(
      color: color ?? tokens.surface,
      borderRadius: AppRadius.cardBorder,
      border: Border.all(color: borderColor ?? tokens.border),
      boxShadow: elevated ? tokens.cardShadow : null,
    );

    final content = Padding(padding: padding, child: child);

    late final Widget built;
    if (onTap == null) {
      built = DecoratedBox(decoration: decoration, child: content);
    } else {
      built = Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.cardBorder,
            child: content,
          ),
        ),
      );
    }

    if (semanticLabel == null) return built;
    return Semantics(button: onTap != null, label: semanticLabel, child: built);
  }
}
