@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/theme/app_theme.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_page.dart';
import 'package:spy_love/shared/widgets/app_text_field.dart';
import 'package:spy_love/shared/widgets/confirm_device_action_sheet.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/features/audit/models/audit_log_model.dart';
import 'package:spy_love/features/audit/repositories/audit_repository.dart';
import 'package:spy_love/features/audit/views/audit_log_view.dart';
import 'package:spy_love/features/devices/models/device_event_model.dart';
import 'package:spy_love/features/devices/views/event_detail_view.dart';
import 'package:spy_love/features/consent/views/pairing_start_view.dart';
import 'package:spy_love/features/consent/views/pairing_success_view.dart';
import 'package:spy_love/features/subscription/controllers/subscription_controller.dart';
import 'package:spy_love/features/subscription/models/subscription_models.dart';
import 'package:spy_love/features/subscription/views/subscription_plans_view.dart';

/// Second Stitch pass — goldens at 412×915 and 800×1280, light + dark.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sizes = <Size>[Size(412, 915), Size(800, 1280)];

  Future<void> golden(
    WidgetTester tester, {
    required String name,
    required Size size,
    required bool dark,
    required Widget child,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: const TextScaler.linear(1),
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: TickerMode(enabled: false, child: child),
        ),
      ),
    );
    await tester.pump();
    final suffix =
        '${size.width.toInt()}x${size.height.toInt()}_${dark ? 'dark' : 'light'}';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/pass2/${name}_$suffix.png'),
    );
  }

  for (final size in sizes) {
    for (final dark in [false, true]) {
      testWidgets('auth $size ${dark ? 'dark' : 'light'}', (tester) async {
        final email = TextEditingController(text: 'you@familycare.org');
        final password = TextEditingController(text: '••••••••••');
        final tenant = TextEditingController(
          text: 'The Morrison Family Circle',
        );
        addTearDown(email.dispose);
        addTearDown(password.dispose);
        addTearDown(tenant.dispose);
        await golden(
          tester,
          name: 'auth',
          size: size,
          dark: dark,
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const Center(
                  child: Icon(Icons.health_and_safety_rounded, size: 48),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: StatusBadge(
                    label: 'SPY LOVE ECOSYSTEM',
                    tone: StatusTone.info,
                    showDot: false,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Consent-First Device Safety',
                  textAlign: TextAlign.center,
                  style: AppTheme.light.textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: tenant,
                        label: 'Family Circle or Team Workspace',
                      ),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: email,
                        label: 'Caregiver / Admin Email',
                      ),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: password,
                        label: 'Secure Password',
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Continue to Workspace Setup',
                        onPressed: () {},
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Continue with Google',
                        variant: AppButtonVariant.soft,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      });

      testWidgets('pairing hub $size ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await golden(
          tester,
          name: 'pairing-entry-hub',
          size: size,
          dark: dark,
          child: const PairingStartView(),
        );
      });

      testWidgets('pairing success $size ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await golden(
          tester,
          name: 'pairing-complete',
          size: size,
          dark: dark,
          child: const PairingSuccessView(
            deviceName: "Maya's Galaxy S24",
            scopeCount: 9,
          ),
        );
      });

      testWidgets('permissions $size ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await golden(
          tester,
          name: 'permission-prompts',
          size: size,
          dark: dark,
          child: Scaffold(
            appBar: AppBar(
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Grant device permissions'),
                  Text('● MUTUAL TRANSPARENCY ACTIVE'),
                ],
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  'STEP 2 OF 3 · ANDROID SETUP',
                  style: TextStyle(
                    color: AppTheme.light.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Grant Device Permissions',
                  style: AppTheme.light.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.query_stats),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Usage Access')),
                      const StatusBadge(
                        label: 'Required',
                        tone: StatusTone.warning,
                        showDot: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Notification Listener')),
                      const StatusBadge(
                        label: 'Required',
                        tone: StatusTone.warning,
                        showDot: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(label: 'Open system settings', onPressed: () {}),
              ],
            ),
          ),
        );
      });

      testWidgets('subscriptions $size ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await golden(
          tester,
          name: 'subscription-plans',
          size: size,
          dark: dark,
          child: ChangeNotifierProvider<SubscriptionController>.value(
            value: _FakeSubscriptions(),
            child: const SubscriptionPlansView(),
          ),
        );
      });

      testWidgets('audit $size ${dark ? 'dark' : 'light'}', (tester) async {
        await golden(
          tester,
          name: 'audit-log',
          size: size,
          dark: dark,
          child: Provider<AuditRepository>.value(
            value: _FakeAudit(),
            child: const AuditLogView(),
          ),
        );
      });

      testWidgets('event detail $size ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        final event = DeviceEventModel(
          id: 'e1',
          deviceId: 'd1',
          eventType: 'call.incoming',
          eventTimestamp: DateTime(2026, 10, 16, 12, 40),
          payload: {
            'contact_name': 'Mom (Sarah)',
            'direction': 'incoming',
            'duration': 252,
            'number': '+1 555-0101',
          },
        );
        await golden(
          tester,
          name: 'event-detail',
          size: size,
          dark: dark,
          child: EventDetailView(
            args: {
              'event': event,
              'deviceName': "Maya's Galaxy S24",
              'consentActive': true,
            },
          ),
        );
      });

      testWidgets('remove confirm $size ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size),
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: TickerMode(
                enabled: false,
                child: Builder(
                  builder: (context) {
                    return Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () => showDisconnectConfirmSheet(
                            context,
                            deviceName: "Maya's Galaxy S24",
                          ),
                          child: const Text('open'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final suffix =
            '${size.width.toInt()}x${size.height.toInt()}_${dark ? 'dark' : 'light'}';
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/pass2/remove-confirm_$suffix.png'),
        );
      });

      testWidgets('overview shell $size ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await golden(
          tester,
          name: 'device-overview',
          size: size,
          dark: dark,
          child: Scaffold(
            appBar: AppBar(
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('Device Detail'), Text('● CONSENTED LINK')],
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      const CircleAvatar(child: Icon(Icons.smartphone)),
                      const SizedBox(width: 12),
                      const Expanded(child: Text("Maya's Galaxy S24")),
                      StatusBadge.device('active'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Device Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Disconnect & Revoke Pairing',
                  icon: Icons.link_off,
                  variant: AppButtonVariant.soft,
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Delete Device & Purge Historical Logs',
                  icon: Icons.delete_outline,
                  variant: AppButtonVariant.destructive,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
      });

      testWidgets('map shell $size ${dark ? 'dark' : 'light'}', (tester) async {
        await golden(
          tester,
          name: 'device-location-map',
          size: size,
          dark: dark,
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Latest location'),
                      const SizedBox(height: 4),
                      const Text('Westwood High School'),
                      const SizedBox(height: 8),
                      const StatusBadge(
                        label: 'Inside Safe Zone',
                        tone: StatusTone.success,
                        showDot: false,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade100,
                          borderRadius: AppRadius.cardBorder,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.map_outlined, size: 40),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Active Geofence Zones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const StatusBadge(
                      label: '2',
                      tone: StatusTone.info,
                      showDot: false,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppCard(
                  color: null,
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Westwood High')),
                      const StatusBadge(
                        label: 'Inside',
                        tone: StatusTone.success,
                        showDot: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Open Directions',
                  icon: Icons.directions_outlined,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
      });

      testWidgets('sim shell $size ${dark ? 'dark' : 'light'}', (tester) async {
        await golden(
          tester,
          name: 'device-sim',
          size: size,
          dark: dark,
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  elevated: false,
                  child: Row(
                    children: [
                      const Icon(Icons.sim_card_outlined),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('SIM Security')),
                      const StatusBadge(
                        label: 'Swap Alerts On',
                        tone: StatusTone.success,
                        showDot: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Active SIM',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.sim_card),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('+1 (555) 010-8821'),
                            Text('T-Mobile · Slot 1'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      });

      testWidgets('care shell $size ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await golden(
          tester,
          name: 'device-care',
          size: size,
          dark: dark,
          child: Scaffold(
            body: AppPage(
              children: [
                Text(
                  'Device care',
                  style: AppTheme.light.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.battery_charging_full),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Battery & power')),
                      const StatusBadge(
                        label: 'Live vital',
                        tone: StatusTone.success,
                        showDot: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.wifi),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Network & Wi‑Fi')),
                      const StatusBadge(
                        label: 'SSL guard',
                        tone: StatusTone.info,
                        showDot: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Revoke consent & disconnect',
                  icon: Icons.link_off,
                  variant: AppButtonVariant.destructive,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
      });

      testWidgets('pairing code shell $size ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await golden(
          tester,
          name: 'pairing-code',
          size: size,
          dark: dark,
          child: Scaffold(
            appBar: AppBar(title: const Text('Pair monitored device')),
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  'Show this code',
                  style: AppTheme.light.textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    children: [
                      Text(
                        'A7K2QM',
                        style: AppTheme.light.textTheme.displayLarge?.copyWith(
                          letterSpacing: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const StatusBadge(
                        label: 'Waiting for consent',
                        tone: StatusTone.warning,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 160,
                        height: 160,
                        color: Colors.black12,
                        child: const Icon(Icons.qr_code_2, size: 96),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      });

      testWidgets('pairing waiting shell $size ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await golden(
          tester,
          name: 'pairing-waiting',
          size: size,
          dark: dark,
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  color: null,
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Waiting for mutual consent…',
                        style: AppTheme.light.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Keep this screen open while the guardian confirms scopes.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      });
    }
  }
}

class _FakeSubscriptions extends Fake implements SubscriptionController {
  @override
  bool isLoading = false;

  @override
  String errorMessage = '';

  @override
  SubscriptionInfo? current = const SubscriptionInfo(
    planCode: 'family',
    planName: 'Family Care',
    isActive: true,
    priceMonthlyUsd: 9,
    maxDevices: 5,
    maxMembers: 5,
    eventRetentionDays: 30,
    features: ['Mutual audit', 'Safe zones'],
  );

  @override
  List<SubscriptionPlan> plans = const [
    SubscriptionPlan(
      code: 'family',
      name: 'Family Care',
      priceMonthlyUsd: 9,
      maxDevices: 5,
      maxMembers: 5,
      eventRetentionDays: 30,
      features: ['Mutual audit', 'Safe zones'],
    ),
    SubscriptionPlan(
      code: 'team',
      name: 'Team',
      priceMonthlyUsd: 29,
      maxDevices: 20,
      maxMembers: 20,
      eventRetentionDays: 90,
      features: ['Fleet pairing', 'Priority support'],
    ),
  ];

  @override
  Future<void> loadPlans() async {}

  @override
  Future<void> loadCurrent() async {}

  @override
  Future<bool> subscribe(String planCode) async => true;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _FakeAudit extends Fake implements AuditRepository {
  @override
  Future<Either<List<AuditLogModel>, String>> listLogs({
    int pageSize = 100,
  }) async {
    return Left([
      AuditLogModel(
        id: '1',
        action: 'device.pairing.completed',
        resourceType: 'device',
        createdAt: DateTime(2026, 10, 16, 10),
        metadata: const {'device': "Maya's Galaxy"},
      ),
      AuditLogModel(
        id: '2',
        action: 'consent.granted',
        resourceType: 'consent',
        createdAt: DateTime(2026, 10, 15, 18),
        metadata: const {'scopes': '9'},
      ),
    ]);
  }
}
