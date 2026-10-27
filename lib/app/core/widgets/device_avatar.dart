import 'package:flutter/material.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/modules/dashboard/models/device_model.dart';

/// https photo when present; otherwise initials (never server-proxied).
class DeviceAvatar extends StatelessWidget {
  const DeviceAvatar({
    super.key,
    required this.device,
    this.size = AppSpacing.touchMin,
  });

  final DeviceModel device;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final photo = device.httpsPhotoUrl;
    final fg = theme.colorScheme.primary;

    Widget child;
    if (photo != null) {
      child = Image.network(
        photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(
            device.initials,
            style: theme.textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    } else {
      child = Center(
        child: Text(
          device.initials,
          style: theme.textTheme.labelLarge?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
