import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/alerts/controllers/alerts_controller.dart';
import 'package:spy_love/features/alerts/views/alerts_view.dart';
import 'package:spy_love/shared/widgets/responsive_scaffold.dart';
import 'package:spy_love/features/devices/views/account_tab.dart';
import 'package:spy_love/features/devices/views/devices_tab.dart';
import 'package:spy_love/features/devices/views/home_tab.dart';
import 'package:spy_love/features/consent/views/pairing_start_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _index = 0;

  /// Wraps a destination icon with an unread badge when [count] > 0.
  Widget _alertsIcon(IconData icon, int count) {
    final child = Icon(icon);
    if (count <= 0) {
      return Semantics(label: 'Alerts', child: child);
    }
    final unread = count > 99 ? '99+' : '$count';
    return Semantics(
      label: 'Alerts, $unread unread',
      child: Badge(
        label: Text(unread),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useRail = context.layoutSize != AppLayoutSize.compact;
    final unread = context.watch<AlertsController>().unreadCount;

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.devices_outlined),
        selectedIcon: Icon(Icons.devices),
        label: 'Devices',
      ),
      NavigationDestination(
        icon: _alertsIcon(Icons.notifications_outlined, unread),
        selectedIcon: _alertsIcon(Icons.notifications_rounded, unread),
        label: 'Alerts',
      ),
      const NavigationDestination(
        icon: Icon(Icons.qr_code_2_outlined),
        selectedIcon: Icon(Icons.qr_code_2),
        label: 'Pair',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Account',
      ),
    ];

    final rail = [
      const NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: Text('Home'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.devices_outlined),
        selectedIcon: Icon(Icons.devices),
        label: Text('Devices'),
      ),
      NavigationRailDestination(
        icon: _alertsIcon(Icons.notifications_outlined, unread),
        selectedIcon: _alertsIcon(Icons.notifications_rounded, unread),
        label: const Text('Alerts'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.qr_code_2_outlined),
        selectedIcon: Icon(Icons.qr_code_2),
        label: Text('Pair'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: Text('Account'),
      ),
    ];

    final pages = [
      HomeTab(
        onSeeDevices: () => setState(() => _index = 1),
        onPair: () => setState(() => _index = 3),
      ),
      DevicesTab(onPair: () => setState(() => _index = 3)),
      const AlertsView(),
      const PairingStartView(embedded: true),
      const AccountTab(),
    ];

    final body = ScaledTextScope(
      child: IndexedStack(index: _index, children: pages),
    );

    if (useRail) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                destinations: rail,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: destinations,
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}
