import 'package:flutter/material.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';

/// Lays out children in a row when width allows; stacks on narrow viewports.
class AdaptiveMetricRow extends StatelessWidget {
  const AdaptiveMetricRow({
    super.key,
    required this.children,
    this.spacing = AppSpacing.sm,
    this.twoColBreakpoint = 360,
    this.threeColBreakpoint = 520,
  });

  final List<Widget> children;
  final double spacing;
  final double twoColBreakpoint;
  final double threeColBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final useRow = switch (children.length) {
          0 || 1 => false,
          2 => width >= twoColBreakpoint,
          3 => width >= threeColBreakpoint,
          _ => false,
        };

        if (useRow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: children[i]),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              children[i],
            ],
          ],
        );
      },
    );
  }
}
