import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';

/// Centers content with DESIGN.md max-width and page margins.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = AppBreakpoints.ofWidth(constraints.maxWidth);
        final pad = padding ?? EdgeInsets.symmetric(
          horizontal: switch (size) {
            AppLayoutSize.compact => AppSpacing.page,
            AppLayoutSize.medium => AppSpacing.pageTablet,
            AppLayoutSize.expanded => AppSpacing.pageDesktop,
          },
        );
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? AppBreakpoints.maxContentWidth,
            ),
            child: Padding(padding: pad, child: child),
          ),
        );
      },
    );
  }
}

/// Two-pane layout for tablet+: [master] list + optional [detail].
class TwoPaneLayout extends StatelessWidget {
  const TwoPaneLayout({
    super.key,
    required this.master,
    this.detail,
    this.masterFlex = 2,
    this.detailFlex = 3,
  });

  final Widget master;
  final Widget? detail;
  final int masterFlex;
  final int detailFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = AppBreakpoints.ofWidth(constraints.maxWidth);
        if (size == AppLayoutSize.compact || detail == null) {
          return master;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: masterFlex, child: master),
            VerticalDivider(width: 1, color: context.tokens.border),
            Expanded(flex: detailFlex, child: detail!),
          ],
        );
      },
    );
  }
}

/// Clamps text scale so layouts do not overflow at extreme accessibility sizes.
class ScaledTextScope extends StatelessWidget {
  const ScaledTextScope({super.key, required this.child, this.maxScale = 1.5});

  final Widget child;
  final double maxScale;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(1).clamp(0.85, maxScale);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    );
  }
}
