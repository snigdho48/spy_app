import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/responsive_scaffold.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.children,
    this.onRefresh,
    this.padding,
    this.center = true,
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry? padding;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding ?? context.pagePadding,
      children: children,
    );

    final body = center
        ? ResponsiveBody(
            padding: EdgeInsets.zero,
            child: list,
          )
        : list;

    if (onRefresh == null) return body;
    return RefreshIndicator(onRefresh: onRefresh!, child: body);
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final String title;
  final String subtitle;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg, top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[
            badge!,
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  letterSpacing: -0.2,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}
