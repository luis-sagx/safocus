import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';
import 'app_router.dart';

/// Bottom navigation shell: Home | Bloqueo | Estadísticas | Configuración.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _TabItem(
      label: 'Inicio',
      icon: PhosphorIconsRegular.house,
      activeIcon: PhosphorIconsFill.house,
      path: AppRoutes.home,
    ),
    _TabItem(
      label: 'Bloqueo',
      icon: PhosphorIconsRegular.shieldSlash,
      activeIcon: PhosphorIconsFill.shieldSlash,
      path: AppRoutes.blocking,
    ),
    _TabItem(
      label: 'Estadísticas',
      icon: PhosphorIconsRegular.chartBar,
      activeIcon: PhosphorIconsFill.chartBar,
      path: AppRoutes.statistics,
    ),
    _TabItem(
      label: 'Ajustes',
      icon: PhosphorIconsRegular.gear,
      activeIcon: PhosphorIconsFill.gear,
      path: AppRoutes.settings,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _tabs.length; i++) {
      if (loc == _tabs[i].path || (i == 0 && loc == AppRoutes.home)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs.map((tab) {
          final selected = _tabs.indexOf(tab) == index;
          return NavigationDestination(
            icon: Icon(
              tab.icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            selectedIcon: Icon(tab.activeIcon, color: AppColors.primary),
            label: tab.label,
          );
        }).toList(),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}
