import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/blocking/screens/blocking_screen.dart';
import '../features/app_limits/screens/app_limits_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/statistics/screens/statistics_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import 'app_shell.dart';

abstract class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/';
  static const String blocking = '/blocking';
  static const String appLimits = '/app-limits';
  static const String notifications = '/notifications';
  static const String statistics = '/statistics';
  static const String settings = '/settings';
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

GoRouter buildRouter({required bool showOnboarding}) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: showOnboarding ? AppRoutes.onboarding : AppRoutes.home,
    routes: [
      // ── Onboarding (full-screen, no shell) ─────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),

      // ── Main shell with bottom nav ─────────────────────────────────────
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: AppRoutes.blocking,
            builder: (_, __) => const BlockingScreen(),
          ),
          GoRoute(
            path: AppRoutes.appLimits,
            builder: (_, __) => const AppLimitsScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.statistics,
            builder: (_, __) => const StatisticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}
