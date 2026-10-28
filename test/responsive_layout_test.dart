import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/core/theme/app_theme.dart';
import 'package:spy_love/shared/widgets/adaptive_metric_row.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/features/devices/widgets/device_list_tile.dart';
import 'package:spy_love/shared/widgets/metric_card.dart';
import 'package:spy_love/shared/widgets/responsive_scaffold.dart';
import 'package:spy_love/features/devices/models/device_home_snapshot.dart';
import 'package:spy_love/features/devices/models/device_model.dart';

const _sizes = <Size>[Size(360, 640), Size(412, 915), Size(800, 1280)];

const _scales = <double>[1.0, 1.5];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in _sizes) {
    for (final dark in [false, true]) {
      for (final scale in _scales) {
        testWidgets('shell ${size.width.toInt()}x${size.height.toInt()} '
            '${dark ? 'dark' : 'light'} scale $scale', (tester) async {
          final errors = <FlutterErrorDetails>[];
          final old = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.toString();
            if (text.contains('overflowed') || text.contains('RenderFlex')) {
              errors.add(details);
            }
            old?.call(details);
          };

          addTearDown(() => FlutterError.onError = old);
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                home: Scaffold(
                  body: ScaledTextScope(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const OfflineBanner(),
                        const SizedBox(height: 12),
                        const ConnectionErrorState(),
                        const SizedBox(height: 12),
                        AdaptiveMetricRow(
                          children: const [
                            MetricCard(
                              label: 'Active devices',
                              value: '2',
                              caption: 'All consented & synced',
                              icon: Icons.phone_android_outlined,
                            ),
                            MetricCard(
                              label: 'Consent status',
                              value: '100%',
                              caption: 'Healthy',
                              icon: Icons.verified_user_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AdaptiveMetricRow(
                          children: const [
                            MetricCard(
                              label: 'Incoming',
                              value: '4',
                              caption: '40% volume',
                              icon: Icons.call_received,
                            ),
                            MetricCard(
                              label: 'Outgoing',
                              value: '3',
                              caption: '30% volume',
                              icon: Icons.call_made,
                            ),
                            MetricCard(
                              label: 'Blocked',
                              value: '1',
                              caption: 'Spam screened',
                              icon: Icons.block,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DeviceListTile(
                          device: const DeviceModel(
                            id: '1',
                            name: 'Kid Pixel XL Extra Long Name',
                            platform: 'android',
                            status: 'active',
                          ),
                          snapshot: const DeviceHomeSnapshot(
                            batteryPercent: 18,
                            batteryCharging: false,
                            placeLabel: 'Safe Zone: School near the north gate',
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          // StatusBadge pulse animations never settle — one frame is enough.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));

          expect(
            errors,
            isEmpty,
            reason: errors.map((e) => e.exceptionAsString()).join('\n'),
          );
        });
      }
    }
  }
}
