import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import '../../../data/local/local_storage.dart';
import '../../../data/models/app_limit.dart';
import '../../../core/constants/app_constants.dart';
import '../../notifications/services/notification_service.dart';

/// Limit monitor: fires when app is foregrounded + Workmanager in background.
///
/// Foreground: Runs a 60s periodic timer.
/// Background: Workmanager task every 15 min (OS minimum).
class LimitMonitorService {
  static final LimitMonitorService _instance = LimitMonitorService._();
  static LimitMonitorService get instance => _instance;

  LimitMonitorService._();

  Timer? _foregroundTimer;
  final _notified = <String, int>{}; // packageName -> lastNotifiedRemaining

  // ── Workmanager init (call once from main) ───────────────────────────────

  static Future<void> initWorkmanager() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  /// Register the background periodic task.
  static Future<void> registerBackgroundTask() async {
    await Workmanager().registerPeriodicTask(
      AppConstants.taskLimitMonitor,
      AppConstants.taskLimitMonitor,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  /// Cancel background task.
  static Future<void> cancelBackgroundTask() async {
    await Workmanager().cancelByUniqueName(AppConstants.taskLimitMonitor);
  }

  // ── Foreground timer ─────────────────────────────────────────────────────

  void startForegroundMonitor() {
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndNotify();
    });
    // Check immediately on start
    _checkAndNotify();
  }

  void stopForegroundMonitor() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
  }

  // ── Core check logic ─────────────────────────────────────────────────────

  static Future<void> checkAndNotifyStatic() async {
    await NotificationService.instance.init();
    final limits = LocalStorage.instance.getAppLimits();
    await _processLimits(limits);
  }

  void _checkAndNotify() {
    final limits = LocalStorage.instance.getAppLimits();
    _processLimitsSync(limits);
  }

  void _processLimitsSync(List<AppLimit> limits) {
    for (int i = 0; i < limits.length; i++) {
      final limit = limits[i];
      if (!limit.isActive || limit.dailyLimitMinutes <= 0) continue;

      final remaining = limit.remainingMinutes;
      final totalSecs = limit.dailyLimitMinutes * 60;
      final remainingSecs = remaining * 60;

      // Warning notification when < 10 min & crossing into warning zone
      if (remaining < AppConstants.limitWarningMinutes && remaining > 0) {
        final lastNotified = _notified[limit.packageName];
        // Only fire warning once for < 10min threshold per session
        if (lastNotified == null ||
            lastNotified > AppConstants.limitWarningMinutes) {
          NotificationService.instance.showLimitWarning(
            appName: limit.appName,
            remainingMinutes: remaining,
            appIndex: i,
          );
        }
        _notified[limit.packageName] = remaining;
      }

      // Update countdown notification for any active limit
      if (remaining <= AppConstants.limitWarningMinutes && remaining >= 0) {
        NotificationService.instance.updateCountdownNotification(
          appName: limit.appName,
          remainingSeconds: remainingSecs,
          totalSeconds: totalSecs,
          appIndex: i,
        );
      } else {
        // Cancel countdown when >10 min remain
        NotificationService.instance.cancelLimitNotification(i);
      }
    }
  }

  static Future<void> _processLimits(List<AppLimit> limits) async {
    for (int i = 0; i < limits.length; i++) {
      final limit = limits[i];
      if (!limit.isActive || limit.dailyLimitMinutes <= 0) continue;

      final remaining = limit.remainingMinutes;
      final totalSecs = limit.dailyLimitMinutes * 60;
      final remainingSecs = remaining * 60;

      if (remaining < AppConstants.limitWarningMinutes && remaining > 0) {
        await NotificationService.instance.showLimitWarning(
          appName: limit.appName,
          remainingMinutes: remaining,
          appIndex: i,
        );
      }

      if (remaining <= AppConstants.limitWarningMinutes) {
        await NotificationService.instance.updateCountdownNotification(
          appName: limit.appName,
          remainingSeconds: remainingSecs,
          totalSeconds: totalSecs,
          appIndex: i,
        );
      }
    }
  }
}

// ── Workmanager callback (top-level, required) ─────────────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == AppConstants.taskLimitMonitor) {
      try {
        final ls = await LocalStorage.init();
        await LimitMonitorService.checkAndNotifyStatic();
        return Future.value(true);
      } catch (e) {
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}
