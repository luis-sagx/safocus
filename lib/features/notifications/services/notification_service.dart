import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../../data/models/motivational_phrase.dart';
import '../../../core/constants/app_constants.dart';

/// Wraps flutter_local_notifications for SaFocus.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  NotificationService._();

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

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

    // Create channels
    const motivationalChannel = AndroidNotificationChannel(
      AppConstants.notifChannelMotivational,
      'Motivación',
      description: 'Recordatorios motivacionales de SaFocus',
      importance: Importance.defaultImportance,
      showBadge: false,
    );

    const alertsChannel = AndroidNotificationChannel(
      AppConstants.notifChannelAlerts,
      'Alertas de límites',
      description: 'Alertas cuando se alcanzan los límites de uso',
      importance: Importance.high,
      showBadge: true,
    );

    const limitWarningChannel = AndroidNotificationChannel(
      AppConstants.notifChannelLimitWarning,
      'Aviso de límite próximo',
      description: 'Avisa cuando queden menos de 10 minutos del límite',
      importance: Importance.high,
      showBadge: true,
      enableVibration: true,
    );

    const countdownChannel = AndroidNotificationChannel(
      AppConstants.notifChannelCountdown,
      'Cuenta atrás de límite',
      description: 'Notificación persistente con el tiempo restante',
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
    await _plugin.show(
      AppConstants.notifMotivationalId,
      'SaFocus',
      phrase.text,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelMotivational,
          'Motivación',
          channelDescription: 'Recordatorios motivacionales',
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
    await cancelAllMotivational();
    if (phrases.isEmpty) return;

    final active = phrases.where((p) => p.isActive).toList();
    if (active.isEmpty) return;

    final random = Random();
    final phrase = active[random.nextInt(active.length)];

    // Schedule next notification at interval, respecting quiet hours
    var scheduled = DateTime.now().add(Duration(hours: intervalHours));

    // Skip if in quiet period
    if (quietStartHour > quietEndHour) {
      // crosses midnight
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
      'SaFocus',
      phrase.text,
      _toTZDateTime(scheduled),
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelMotivational,
          'Motivación',
          channelDescription: 'Recordatorios motivacionales',
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
    await _plugin.show(
      AppConstants.notifAppLimitId,
      'Límite alcanzado',
      'Has alcanzado el límite diario para $appName.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelAlerts,
          'Alertas de límites',
          channelDescription: 'Alertas de límites de uso',
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

  /// Shows a high-priority notification warning that [remainingMinutes] remain.
  /// [appIndex] is used to give each app a unique notification ID.
  Future<void> showLimitWarning({
    required String appName,
    required int remainingMinutes,
    required int appIndex,
  }) async {
    final body =
        remainingMinutes <= 1
            ? '¡Menos de 1 minuto restante para $appName!'
            : '$remainingMinutes minutos restantes para $appName';

    await _plugin.show(
      AppConstants.notifLimitWarningBase + appIndex,
      '⏰ Límite próximo',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelLimitWarning,
          'Aviso de límite próximo',
          channelDescription: 'Avisa cuando queden menos de 10 min',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          ticker: 'Límite próximo para $appName',
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

  // ── Countdown notification (progress bar + MM:SS) ────────────────────────

  /// Updates an ongoing notification with the remaining time as MM:SS
  /// and a progress bar. Call this every minute (or every second for < 2min).
  Future<void> updateCountdownNotification({
    required String appName,
    required int remainingSeconds,
    required int totalSeconds,
    required int appIndex,
  }) async {
    final mins = remainingSeconds ~/ 60;
    final secs = remainingSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final progress =
        (totalSeconds > 0)
            ? ((totalSeconds - remainingSeconds) / totalSeconds * 100).round()
            : 100;

    final body =
        remainingSeconds <= 0
            ? '¡Límite alcanzado!'
            : 'Tiempo restante: $timeStr';

    await _plugin.show(
      AppConstants.notifCountdownBase + appIndex,
      appName,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelCountdown,
          'Cuenta atrás de límite',
          channelDescription: 'Muestra el tiempo restante',
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
    // Cancel all per-app limit notifications (up to 20 apps)
    for (int i = 0; i < 20; i++) {
      await _plugin.cancel(AppConstants.notifLimitWarningBase + i);
      await _plugin.cancel(AppConstants.notifCountdownBase + i);
    }
  }

  // ── Request permission ───────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  // ── Helper: convert DateTime to tz.TZDateTime ──────────────────────────

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
