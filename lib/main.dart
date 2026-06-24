import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/local/local_storage.dart';
import 'features/app_limits/services/limit_monitor_service.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/notifications/services/notification_service.dart';
import 'features/settings/providers/settings_provider.dart';
import 'navigation/app_router.dart';

// Global router reference for deep-link navigation from notifications.
GoRouter? _globalRouter;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Init storage
  await LocalStorage.init();

  // Init notifications
  await NotificationService.instance.init();

  // Wire notification deep link -> router navigation
  NotificationService.onNavigate = (route) {
    _globalRouter?.go(route);
  };

  // Init Workmanager for background limit monitoring
  await LimitMonitorService.initWorkmanager();

  // Check onboarding
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool(AppConstants.keyOnboardingDone) ?? false;

  runApp(ProviderScope(child: SaFocusApp(showOnboarding: !onboardingDone)));
}

class SaFocusApp extends ConsumerStatefulWidget {
  const SaFocusApp({super.key, required this.showOnboarding});

  final bool showOnboarding;

  @override
  ConsumerState<SaFocusApp> createState() => _SaFocusAppState();
}

class _SaFocusAppState extends ConsumerState<SaFocusApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(showOnboarding: widget.showOnboarding);
    _globalRouter = _router;
    WidgetsBinding.instance.addObserver(this);

    // Handle emergency extension requests from BlockOverlayActivity (native)
    const blockCh = MethodChannel(AppConstants.channelBlockControl);
    blockCh.setMethodCallHandler((call) async {
      if (call.method == 'emergencyExtRequest') {
        _globalRouter?.go(AppConstants.routeAppLimits);
      }
    });

    // Start foreground limit monitor
    LimitMonitorService.instance.startForegroundMonitor();

    // Register background task if there are active limits
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final limits = LocalStorage.instance.getAppLimits();
      if (limits.any((l) => l.isActive)) {
        LimitMonitorService.registerBackgroundTask();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LimitMonitorService.instance.stopForegroundMonitor();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LimitMonitorService.instance.startForegroundMonitor();
    } else if (state == AppLifecycleState.paused) {
      LimitMonitorService.instance.stopForegroundMonitor();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: settings.flutterThemeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: _router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      locale: Locale(settings.language),
      builder: (context, child) {
        // Keep the status bar icons legible in both themes (the app has many
        // screens without an AppBar to drive systemOverlayStyle).
        final isLight = Theme.of(context).brightness == Brightness.light;
        final overlay = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        );
        final content = _isLocked
            ? AuthScreen(
                onAuthenticated: () async {
                  setState(() => _isLocked = false);
                },
              )
            : (child ?? const SizedBox.shrink());
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: content,
        );
      },
    );
  }
}
