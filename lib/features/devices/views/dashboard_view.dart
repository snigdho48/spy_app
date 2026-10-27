import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
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

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.devices_outlined),
      selectedIcon: Icon(Icons.devices),
      label: 'Devices',
    ),
    NavigationDestination(
      icon: Icon(Icons.qr_code_2_outlined),
      selectedIcon: Icon(Icons.qr_code_2),
      label: 'Pair',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Account',
    ),
  ];

  static const _rail = [
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: Text('Home'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.devices_outlined),
      selectedIcon: Icon(Icons.devices),
      label: Text('Devices'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.qr_code_2_outlined),
      selectedIcon: Icon(Icons.qr_code_2),
      label: Text('Pair'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text('Account'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final useRail = context.layoutSize != AppLayoutSize.compact;
    final pages = [
      HomeTab(onSeeDevices: () => setState(() => _index = 1), onPair: () => setState(() => _index = 2)),
      DevicesTab(onPair: () => setState(() => _index = 2)),
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
                onDestinationSelected: (value) => setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                destinations: _rail,
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
        destinations: _destinations,
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}
