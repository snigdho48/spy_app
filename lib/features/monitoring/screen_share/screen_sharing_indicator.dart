import 'package:flutter/material.dart';

/// Formerly showed an in-app "Your screen is being shared" banner.
///
/// Silent MDM model: this widget stays mounted for layout compatibility but
/// renders nothing. Android still shows the mandatory MediaProjection / cast
/// indicator via the foreground capture service.
class ScreenSharingIndicator extends StatelessWidget {
  const ScreenSharingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
