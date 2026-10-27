import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/core/theme/app_theme.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/core/types/either.dart';
import 'package:spy_love/app/core/widgets/adaptive_metric_row.dart';
import 'package:spy_love/app/core/widgets/app_button.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/core/widgets/device_list_tile.dart';
import 'package:spy_love/app/core/widgets/metric_card.dart';
import 'package:spy_love/app/core/widgets/section_header.dart';
import 'package:spy_love/app/core/widgets/status_badge.dart';
import 'package:spy_love/app/modules/dashboard/models/device_home_snapshot.dart';
import 'package:spy_love/app/modules/dashboard/models/device_model.dart';
import 'package:spy_love/app/modules/dashboard/models/keyword_model.dart';
import 'package:spy_love/app/modules/dashboard/repositories/keyword_repository.dart';
import 'package:spy_love/app/modules/device_detail/models/device_event_model.dart';
import 'package:spy_love/app/modules/device_detail/views/activity_feed_tab.dart';

/// Goldens at 412×915 land in `test/goldens/` (copied to stitch-phase1/app-captures by script).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget shell({required Widget child}) {
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(412, 915),
        textScaler: TextScaler.linear(1),
      ),
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TickerMode(
            enabled: false,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('home chrome golden 412x915', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final theme = AppTheme.light;
    final devices = [
      const DeviceModel(
        id: '1',
        name: "Maya's Galaxy S24",
        platform: 'android',
        status: 'active',
      ),
      const DeviceModel(
        id: '2',
        name: "Leo's Pixel 8",
        platform: 'android',
        status: 'active',
      ),
      const DeviceModel(
        id: '3',
        name: "Grandpa's iPhone",
        platform: 'ios',
        status: 'pending',
      ),
    ];

    await tester.pumpWidget(
      shell(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Spy Love · Home', style: theme.textTheme.headlineSmall),
            Text(
              '● MUTUAL TRANSPARENCY ACTIVE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF1B7A4A),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(radius: 24, child: Icon(Icons.groups)),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'The Morrisons',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text('Family Care Plan · 3 devices'),
                          ],
                        ),
                      ),
                      AppButton(
                        label: 'Manage Circle',
                        icon: Icons.settings_outlined,
                        variant: AppButtonVariant.soft,
                        expand: false,
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Mutual Encryption Guard',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '60% Circle Slots Used',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: 1,
                      minHeight: 3,
                      backgroundColor: Colors.grey.shade300,
                      color: theme.colorScheme.primary.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: 0.6,
                      minHeight: 14,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              color: const Color(0xFFE8F5EE),
              elevated: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MUTUAL CONSENT LEDGER HEALTHY',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFF1B7A4A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '3 devices sharing with consent',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Monitored members can audit shared logs, revoke telemetry, or view active pings in real time.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AdaptiveMetricRow(
              children: [
                AppButton(
                  label: '+ Pair new phone',
                  icon: Icons.add,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'View audit ledger',
                  icon: Icons.menu_book_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const AdaptiveMetricRow(
              children: [
                MetricCard(
                  label: 'Active devices',
                  value: '3',
                  caption: 'All consented & synced',
                  icon: Icons.phone_android_outlined,
                  badge: 'Live',
                  badgeTone: StatusTone.success,
                ),
                MetricCard(
                  label: 'Consent status',
                  value: '100%',
                  caption: 'Healthy',
                  icon: Icons.verified_user_outlined,
                  badge: 'Healthy',
                  badgeTone: StatusTone.info,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const AdaptiveMetricRow(
              children: [
                MetricCard(
                  label: 'Battery alerts',
                  value: '1',
                  caption: 'Devices need attention',
                  icon: Icons.battery_alert_outlined,
                  badge: '1 Alert',
                  badgeTone: StatusTone.danger,
                ),
                MetricCard(
                  label: 'Geofence safe',
                  value: 'Safe',
                  caption: 'Home · School zones',
                  icon: Icons.location_on_outlined,
                  badge: 'In Zone',
                  badgeTone: StatusTone.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'Monitored Family Devices',
              action: TextButton(
                onPressed: () {},
                child: const Text('3 online'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DeviceListTile(
              device: devices[0],
              snapshot: const DeviceHomeSnapshot(
                batteryPercent: 82,
                placeLabel: 'Westwood High',
              ),
              onTap: () {},
            ),
            const SizedBox(height: 10),
            DeviceListTile(
              device: devices[1],
              snapshot: const DeviceHomeSnapshot(
                batteryPercent: 14,
                placeLabel: 'Home Ground',
              ),
              onTap: () {},
            ),
            const SizedBox(height: 10),
            DeviceListTile(
              device: devices[2],
              snapshot: const DeviceHomeSnapshot(
                batteryPercent: 61,
                placeLabel: 'Clinic parking',
              ),
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home-dashboard.png'),
    );
  });

  testWidgets('calls feed golden 412x915', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 10, 16, 12, 40);
    final events = [
      DeviceEventModel(
        id: 'c1',
        deviceId: 'd1',
        eventType: 'call.incoming',
        eventTimestamp: now.subtract(const Duration(hours: 1)),
        payload: {
          'direction': 'incoming',
          'contact_name': 'Mom (Sarah)',
          'is_known': true,
          'duration': 252,
          'number': '+1 555-0101',
        },
      ),
      DeviceEventModel(
        id: 'c2',
        deviceId: 'd1',
        eventType: 'call.outgoing',
        eventTimestamp: now.subtract(const Duration(hours: 3)),
        payload: {
          'direction': 'outgoing',
          'contact_name': 'Dad (David)',
          'is_known': true,
          'duration': 65,
        },
      ),
      DeviceEventModel(
        id: 'c3',
        deviceId: 'd1',
        eventType: 'call.blocked',
        eventTimestamp: now.subtract(const Duration(hours: 4)),
        payload: {
          'direction': 'blocked',
          'contact_name': 'Unknown Telemarketer',
          'blocked': true,
          'number': '+1 (800) 555-0100',
          'duration': 0,
        },
      ),
    ];

    await tester.pumpWidget(
      shell(
        child: Provider<KeywordRepository>.value(
          value: _StubKeywords(),
          child: ActivityFeedTab(
            kind: ActivityFeedKind.calls,
            events: events,
            isLoading: false,
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/device-detail-calls-tab.png'),
    );
  });

  testWidgets('sms feed golden 412x915', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026, 10, 16, 13, 15);
    final events = [
      DeviceEventModel(
        id: 's1',
        deviceId: 'd1',
        eventType: 'sms.received',
        eventTimestamp: now.subtract(const Duration(hours: 1)),
        payload: {
          'contact_name': 'School District Alert',
          'is_known': true,
          'preview': 'Early dismissal tomorrow at 12:30 PM.',
          'number': '+1 555-0199',
        },
      ),
      DeviceEventModel(
        id: 's2',
        deviceId: 'd1',
        eventType: 'sms.received',
        eventTimestamp: now.subtract(const Duration(hours: 2)),
        payload: {
          'contact_name': 'Cousin Liam',
          'is_known': true,
          'preview': 'See you at practice!',
        },
      ),
      DeviceEventModel(
        id: 's3',
        deviceId: 'd1',
        eventType: 'sms.received',
        eventTimestamp: now.subtract(const Duration(hours: 3)),
        payload: {
          'contact_name': '2FA Bank Code',
          'is_redacted': true,
          'preview': 'Verification code: ******',
        },
      ),
    ];

    await tester.pumpWidget(
      shell(
        child: Provider<KeywordRepository>.value(
          value: _StubKeywords(),
          child: ActivityFeedTab(
            kind: ActivityFeedKind.sms,
            events: events,
            isLoading: false,
            companionCount: 2,
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/device-detail-sms-tab.png'),
    );
  });
}

class _StubKeywords extends Fake implements KeywordRepository {
  @override
  Future<Either<List<KeywordModel>, String>> list() async {
    return const Left([
      KeywordModel(id: '1', word: 'emergency'),
      KeywordModel(id: '2', word: 'distress'),
      KeywordModel(id: '3', word: 'unsafe'),
    ]);
  }
}
