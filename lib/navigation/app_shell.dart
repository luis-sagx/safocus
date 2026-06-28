import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safocus/core/icons/phosphor_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../core/localization/app_strings.dart';
import 'app_router.dart';

/// Bottom navigation shell: Home | Bloqueo | Estadísticas | Configuración.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  List<_TabItem> _tabs(AppStrings strings) => [
    _TabItem(
      label: strings.home,
      icon: PhosphorIconsRegular.house,
      activeIcon: PhosphorIconsFill.house,
      path: AppRoutes.home,
    ),
    _TabItem(
      label: strings.blocking,
      icon: PhosphorIconsRegular.shieldSlash,
      activeIcon: PhosphorIconsFill.shieldSlash,
      path: AppRoutes.blocking,
    ),
    _TabItem(
      label: strings.statistics,
      icon: PhosphorIconsRegular.chartBar,
      activeIcon: PhosphorIconsFill.chartBar,
      path: AppRoutes.statistics,
    ),
    _TabItem(
      label: strings.limits,
      icon: PhosphorIconsRegular.clockCountdown,
      activeIcon: PhosphorIconsFill.clockCountdown,
      path: AppRoutes.appLimits,
    ),
    _TabItem(
      label: strings.settings,
      icon: PhosphorIconsRegular.gear,
      activeIcon: PhosphorIconsFill.gear,
      path: AppRoutes.settings,
    ),
  ];

  int _currentIndex(BuildContext context, List<_TabItem> tabs) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith(AppRoutes.statistics)) return 2;
    for (int i = 0; i < tabs.length; i++) {
      if (loc == tabs[i].path || (i == 0 && loc == AppRoutes.home)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final tabs = _tabs(strings);
    final index = _currentIndex(context, tabs);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          // smaller labels
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 11),
          ),
          // remove the default selection indicator background color
          indicatorColor: Colors.transparent,
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => context.go(tabs[i].path),
          destinations: tabs.map((tab) {
            final selected = tabs.indexOf(tab) == index;
            return NavigationDestination(
              icon: Icon(
                tab.icon,
                color: selected ? AppColors.primary : context.colors.textSecondary,
              ),
              selectedIcon: Icon(tab.activeIcon, color: AppColors.primary),
              label: tab.label,
            );
          }).toList(),
        ),
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
