import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/local_storage.dart';
import '../../../data/models/app_limit.dart';
import '../../../core/constants/app_constants.dart';

class AppLimitsState {
  final List<AppLimit> limits;
  final bool isLoading;
  final bool hasUsagePermission;
  final bool hasOverlayPermission;

  const AppLimitsState({
    this.limits = const [],
    this.isLoading = false,
    this.hasUsagePermission = true,
    this.hasOverlayPermission = true,
  });

  AppLimitsState copyWith({
    List<AppLimit>? limits,
    bool? isLoading,
    bool? hasUsagePermission,
    bool? hasOverlayPermission,
  }) => AppLimitsState(
    limits: limits ?? this.limits,
    isLoading: isLoading ?? this.isLoading,
    hasUsagePermission: hasUsagePermission ?? this.hasUsagePermission,
    hasOverlayPermission: hasOverlayPermission ?? this.hasOverlayPermission,
  );

  bool get allPermissionsGranted => hasUsagePermission && hasOverlayPermission;
}

class AppLimitsNotifier extends StateNotifier<AppLimitsState> {
  AppLimitsNotifier() : super(const AppLimitsState()) {
    _init();
  }

  static const _usageChannel = MethodChannel(AppConstants.channelUsage);
  static const _blockChannel = MethodChannel(AppConstants.channelBlockControl);

  // ── Initialisation ───────────────────────────────────────────────────────

  Future<void> _init() async {
    _load();
    await _checkPermissions();
    await _checkAndResetIfNewDay();
    await _refreshUsageStats();
    await _startServiceIfPermitted();
    await _scheduleResetAlarm();
  }

  void _load() {
    final limits = LocalStorage.instance.getAppLimits();
    state = state.copyWith(limits: limits);
  }

  // ── Permission checks ────────────────────────────────────────────────────

  Future<void> _checkPermissions() async {
    try {
      final usage =
          await _blockChannel.invokeMethod<bool>('hasUsagePermission') ?? false;
      final overlay =
          await _blockChannel.invokeMethod<bool>('hasOverlayPermission') ??
          false;
      state = state.copyWith(
        hasUsagePermission: usage,
        hasOverlayPermission: overlay,
      );
    } on PlatformException catch (_) {
      // Non-Android or channel unavailable — assume granted.
    }
  }

  Future<void> refreshPermissions() => _checkPermissions();

  Future<void> openUsageSettings() async {
    try {
      await _blockChannel.invokeMethod('openUsageSettings');
    } catch (_) {}
  }

  Future<void> openOverlaySettings() async {
    try {
      await _blockChannel.invokeMethod('openOverlaySettings');
    } catch (_) {}
  }

  // ── Start ForegroundService ──────────────────────────────────────────────

  Future<void> _startServiceIfPermitted() async {
    if (!state.hasUsagePermission) return;
    try {
      await _blockChannel.invokeMethod('startUsageMonitor');
    } catch (_) {}
  }

  // ── Midnight reset alarm ─────────────────────────────────────────────────

  Future<void> _scheduleResetAlarm() async {
    try {
      await _blockChannel.invokeMethod('scheduleResetAlarm');
    } catch (_) {}
  }

  // ── Guayaquil-aware daily reset (Mechanism 2) ────────────────────────────

  /// Returns today's date string in America/Guayaquil timezone (UTC-5, no DST).
  static String _todayGuayaquil() {
    final guayaquil = DateTime.now().toUtc().add(AppConstants.guayaquilOffset);
    return '${guayaquil.year.toString().padLeft(4, '0')}'
        '-${guayaquil.month.toString().padLeft(2, '0')}'
        '-${guayaquil.day.toString().padLeft(2, '0')}';
  }

  Future<void> _checkAndResetIfNewDay() async {
    final today = _todayGuayaquil();
    final lastReset = LocalStorage.instance.getString(
      AppConstants.keyLastDailyReset,
    );
    if (lastReset != today) {
      await resetDailyCounters();
      await LocalStorage.instance.setString(
        AppConstants.keyLastDailyReset,
        today,
      );
      try {
        await _blockChannel.invokeMethod('resetExtUsed');
      } catch (_) {}
    }
  }

  // ── Query Android UsageStats ─────────────────────────────────────────────

  Future<void> _refreshUsageStats() async {
    if (!state.hasUsagePermission) return;
    try {
      final result = await _usageChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getTodayUsage',
      );
      if (result == null) return;

      final current =
          state.limits.map((limit) {
            final minutes = (result[limit.packageName] as int?) ?? 0;
            return limit.copyWith(usedMinutesToday: minutes);
          }).toList();

      await LocalStorage.instance.saveAppLimits(current);
      state = state.copyWith(limits: current);

      // Push exceeded list to native so UsageMonitorService blocks them.
      await _syncBlockStateToNative(current);
    } on PlatformException catch (_) {
      // Not on Android or permission revoked — use stored values.
    }
  }

  /// Writes the exceeded-apps list to native SharedPreferences so
  /// UsageMonitorService can read it directly without a channel round-trip.
  Future<void> _syncBlockStateToNative(List<AppLimit> limits) async {
    try {
      final exceeded =
          limits
              .where((l) => l.isActive && l.isExceeded)
              .map(
                (l) => {
                  'packageName': l.packageName,
                  'appName': l.appName,
                  'usedMinutes': l.usedMinutesToday,
                  'limitMinutes': l.dailyLimitMinutes,
                },
              )
              .toList();
      await _blockChannel.invokeMethod('syncExceededApps', {'apps': exceeded});
    } catch (_) {}
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> addLimit({
    required String packageName,
    required String appName,
    required int dailyLimitMinutes,
  }) async {
    final limit = AppLimit(
      packageName: packageName,
      appName: appName,
      dailyLimitMinutes: dailyLimitMinutes,
    );
    await LocalStorage.instance.upsertAppLimit(limit);
    _load();
  }

  Future<void> updateLimit(AppLimit limit) async {
    await LocalStorage.instance.upsertAppLimit(limit);
    _load();
  }

  Future<void> deleteLimit(String id) async {
    await LocalStorage.instance.deleteAppLimit(id);
    _load();
  }

  Future<void> toggleLimit(AppLimit limit) async {
    await LocalStorage.instance.upsertAppLimit(
      limit.copyWith(isActive: !limit.isActive),
    );
    _load();
  }

  // ── Emergency extension ──────────────────────────────────────────────────

  Future<bool> requestEmergencyExtension(String limitId) async {
    final limit = state.limits.firstWhere((l) => l.id == limitId);
    if (limit.emergencyExtUsedToday) return false;

    final extended = limit.copyWith(
      emergencyExtUsedToday: true,
      dailyLimitMinutes:
          limit.dailyLimitMinutes + AppConstants.emergencyExtensionMinutes,
    );
    await LocalStorage.instance.upsertAppLimit(extended);
    _load();
    // Re-sync so the block is lifted immediately.
    await _syncBlockStateToNative(state.limits);
    return true;
  }

  // ── Daily reset ──────────────────────────────────────────────────────────

  Future<void> resetDailyCounters() async {
    final reset =
        state.limits
            .map(
              (l) =>
                  l.copyWith(usedMinutesToday: 0, emergencyExtUsedToday: false),
            )
            .toList();
    await LocalStorage.instance.saveAppLimits(reset);
    _load();
  }

  Future<void> refresh() async {
    await _checkPermissions();
    await _checkAndResetIfNewDay();
    await _refreshUsageStats();
    await _startServiceIfPermitted();
  }
}

final appLimitsProvider =
    StateNotifierProvider<AppLimitsNotifier, AppLimitsState>(
      (ref) => AppLimitsNotifier(),
    );
