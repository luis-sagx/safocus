import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_strings.dart';
import '../../../data/local/local_storage.dart';
import '../../../data/models/motivational_phrase.dart';

/// Wraps flutter_local_notifications for SaFocus.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  NotificationService._();

  AppStrings get _strings => AppStrings.forLanguage(
    LocalStorage.instance.getString(AppConstants.keyLanguage) ?? 'es',
  );

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Guayaquil'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final strings = _strings;

    final motivationalChannel = AndroidNotificationChannel(
      AppConstants.notifChannelMotivational,
      strings.motivation,
      description: strings.receiveMotivationalPhrases,
      importance: Importance.defaultImportance,
      showBadge: false,
    );

    final alertsChannel = AndroidNotificationChannel(
      AppConstants.notifChannelAlerts,
      strings.appLimitScreenTitle,
      description:
          strings.isEnglish
              ? 'Comeback reminders when you hit a limit'
              : 'Recordatorios de comeback al llegar al límite',
      importance: Importance.high,
      showBadge: true,
    );

    final limitWarningChannel = AndroidNotificationChannel(
      AppConstants.notifChannelLimitWarning,
      strings.isEnglish ? 'Limit warning' : 'Aviso de límite próximo',
      description:
          strings.isEnglish
              ? 'Warns when fewer than 10 minutes remain'
              : 'Avisa cuando queden menos de 10 minutos del límite',
      importance: Importance.high,
      showBadge: true,
      enableVibration: true,
    );

    final countdownChannel = AndroidNotificationChannel(
      AppConstants.notifChannelCountdown,
      strings.timeLimit,
      description:
          strings.isEnglish
              ? 'Persistent notification with the remaining time'
              : 'Notificación persistente con el tiempo restante',
      importance: Importance.low,
      showBadge: false,
      enableVibration: false,
    );

    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidPlugin?.createNotificationChannel(motivationalChannel);
    await androidPlugin?.createNotificationChannel(alertsChannel);
    await androidPlugin?.createNotificationChannel(limitWarningChannel);
    await androidPlugin?.createNotificationChannel(countdownChannel);

    _initialized = true;
    await requestPermission();
  }

  // Navigation callback key for deep linking
  static const String appLimitsRoute = '/app-limits';
  static void Function(String route)? onNavigate;

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('route:')) {
      final route = payload.substring(6);
      onNavigate?.call(route);
    }
  }

  // ── Motivational ─────────────────────────────────────────────────────────

  Future<void> showMotivationalNow(MotivationalPhrase phrase) async {
    final strings = _strings;
    await _plugin.show(
      AppConstants.notifMotivationalId,
      strings.appName,
      phrase.text,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelMotivational,
          strings.motivation,
          channelDescription: strings.receiveMotivationalPhrases,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(phrase.text),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> scheduleMotivational({
    required List<MotivationalPhrase> phrases,
    required int intervalHours,
    required int quietStartHour,
    required int quietEndHour,
  }) async {
    final strings = _strings;
    await cancelAllMotivational();
    if (phrases.isEmpty) return;

    final active = phrases.where((p) => p.isActive).toList();
    if (active.isEmpty) return;

    final random = Random();
    final phrase = active[random.nextInt(active.length)];

    var scheduled = DateTime.now().add(Duration(hours: intervalHours));
    if (quietStartHour > quietEndHour) {
      if (scheduled.hour >= quietStartHour || scheduled.hour < quietEndHour) {
        scheduled = DateTime(
          scheduled.year,
          scheduled.month,
          scheduled.day,
          quietEndHour,
        );
        if (scheduled.isBefore(DateTime.now())) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
      }
    }

    await _plugin.zonedSchedule(
      AppConstants.notifMotivationalId,
      strings.appName,
      phrase.text,
      _toTZDateTime(scheduled),
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelMotivational,
          strings.motivation,
          channelDescription: strings.receiveMotivationalPhrases,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(phrase.text),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAllMotivational() async {
    await _plugin.cancel(AppConstants.notifMotivationalId);
  }

  // ── App limit alert ──────────────────────────────────────────────────────

  Future<void> showAppLimitReached(String appName) async {
    final strings = _strings;
    await _plugin.show(
      AppConstants.notifAppLimitId,
      strings.limitReachedTitle,
      strings.limitReachedBody(appName),
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelAlerts,
          strings.appLimitScreenTitle,
          channelDescription:
              strings.isEnglish
                  ? 'Comeback reminders when you hit a limit'
                  : 'Recordatorios de comeback al llegar al límite',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ── Limit warning (< 10 min left) ────────────────────────────────────────

  Future<void> showLimitWarning({
    required String appName,
    required int remainingMinutes,
    required int appIndex,
  }) async {
    final strings = _strings;

    await _plugin.show(
      AppConstants.notifLimitWarningBase + appIndex,
      strings.limitWarningTitle,
      strings.limitWarningBody(appName, remainingMinutes),
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelLimitWarning,
          strings.isEnglish ? 'Limit warning' : 'Aviso de límite próximo',
          channelDescription:
              strings.isEnglish
                  ? 'Warns when fewer than 10 minutes remain'
                  : 'Avisa cuando queden menos de 10 min',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          ticker:
              strings.isEnglish
                  ? 'Limit soon for $appName'
                  : 'Límite próximo para $appName',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'route:${AppConstants.routeAppLimits}',
    );
  }

  Future<void> updateCountdownNotification({
    required String appName,
    required int remainingSeconds,
    required int totalSeconds,
    required int appIndex,
  }) async {
    final strings = _strings;
    final mins = remainingSeconds ~/ 60;
    final secs = remainingSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final progress =
        totalSeconds > 0
            ? ((totalSeconds - remainingSeconds) / totalSeconds * 100).round()
            : 100;

    final body =
        remainingSeconds <= 0
            ? (strings.isEnglish ? 'Limit reached!' : '¡Límite alcanzado!')
            : (strings.isEnglish
                ? 'Time left: $timeStr'
                : 'Tiempo restante: $timeStr');

    await _plugin.show(
      AppConstants.notifCountdownBase + appIndex,
      appName,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelCountdown,
          strings.timeLimit,
          channelDescription:
              strings.isEnglish
                  ? 'Shows the remaining time'
                  : 'Muestra el tiempo restante',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: remainingSeconds > 0,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      payload: 'route:${AppConstants.routeAppLimits}',
    );
  }

  Future<void> cancelLimitNotification(int appIndex) async {
    await _plugin.cancel(AppConstants.notifLimitWarningBase + appIndex);
    await _plugin.cancel(AppConstants.notifCountdownBase + appIndex);
  }

  Future<void> cancelAllLimitNotifications() async {
    for (int i = 0; i < 20; i++) {
      await _plugin.cancel(AppConstants.notifLimitWarningBase + i);
      await _plugin.cancel(AppConstants.notifCountdownBase + i);
    }
  }

  Future<bool> requestPermission() async {
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  tz.TZDateTime _toTZDateTime(DateTime dt) {
    final location = tz.local;
    return tz.TZDateTime(
      location,
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
    );
  }
}
