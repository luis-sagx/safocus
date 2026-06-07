import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/focus_score.dart' as sf;
import '../../../data/local/local_storage.dart';
import '../../../data/models/app_category.dart';
import '../../../data/models/app_limit.dart';
import '../../../data/models/usage_stat.dart';

class AppLimitsState {
  final List<AppLimit> limits;
  final bool isLoading;
  final bool hasUsagePermission;
  final bool hasOverlayPermission;

  /// Map of categoryId → total usedMinutesToday (aggregate across all apps).
  final Map<String, int> categoryUsage;

  /// Category IDs whose total usage exceeds their daily limit.
  final Set<String> exceededCategoryIds;

  const AppLimitsState({
    this.limits = const [],
    this.isLoading = false,
    this.hasUsagePermission = true,
    this.hasOverlayPermission = true,
    this.categoryUsage = const {},
    this.exceededCategoryIds = const {},
  });

  AppLimitsState copyWith({
    List<AppLimit>? limits,
    bool? isLoading,
    bool? hasUsagePermission,
    bool? hasOverlayPermission,
    Map<String, int>? categoryUsage,
    Set<String>? exceededCategoryIds,
  }) => AppLimitsState(
    limits: limits ?? this.limits,
    isLoading: isLoading ?? this.isLoading,
    hasUsagePermission: hasUsagePermission ?? this.hasUsagePermission,
    hasOverlayPermission: hasOverlayPermission ?? this.hasOverlayPermission,
    categoryUsage: categoryUsage ?? this.categoryUsage,
    exceededCategoryIds: exceededCategoryIds ?? this.exceededCategoryIds,
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

      // ── 3.3: Compute per-category usage totals ──────────────────────────
      final categories = LocalStorage.instance.getAppCategories(seed: false);
      final categoryUsage = <String, int>{};
      final exceededCategoryIds = <String>{};

      for (final cat in categories) {
        final usage = current
            .where((l) => l.categoryId == cat.id)
            .fold<int>(0, (sum, l) => sum + l.usedMinutesToday);
        categoryUsage[cat.id] = usage;
        if (cat.dailyLimitMinutes > 0 && usage >= cat.dailyLimitMinutes) {
          exceededCategoryIds.add(cat.id);
        }
      }

      state = state.copyWith(
        limits: current,
        categoryUsage: categoryUsage,
        exceededCategoryIds: exceededCategoryIds,
      );

      // ── 3.5: Focus score per category (ALC-009) ─────────────────────────
      final today = DateTime.now();
      final normalizedDay = DateTime(today.year, today.month, today.day);
      final vpnActive = LocalStorage.instance.getBool(AppConstants.keyVpnEnabled);

      // Active categories: have limit > 0 AND have active apps assigned
      final activeCategories = categories.where((c) {
        final appsInCat = current
            .where((l) => l.categoryId == c.id && l.isActive)
            .length;
        return c.dailyLimitMinutes > 0 && appsInCat > 0;
      }).toList();

      final respectedCategories = activeCategories.where((c) {
        return !exceededCategoryIds.contains(c.id);
      }).length;

      final respectedRatio = activeCategories.isEmpty
          ? 1.0
          : respectedCategories / activeCategories.length;

      final focusScore = sf.calculateFocusScore(
        vpnActive: vpnActive,
        limitsRespectedRatio: respectedRatio,
        notificationsInteracted: false,
      );

      for (final limit in current.where(
        (limit) => limit.isActive && limit.effectiveLimitMinutes > 0,
      )) {
        await LocalStorage.instance.upsertUsageStat(
          DailyUsageStat(
            date: normalizedDay,
            packageName: limit.packageName,
            appName: limit.appName,
            usageMinutes: limit.usedMinutesToday,
            focusScore: focusScore,
          ),
        );
      }

      // Push exceeded list to native so UsageMonitorService blocks them.
      await _syncBlockStateToNative(current);
    } on PlatformException catch (_) {
      // Not on Android or permission revoked — use stored values.
    }
  }

  // ── 3.4: Flatten exceeded from categories ────────────────────────────────

  /// Writes the exceeded-apps list to native SharedPreferences so
  /// UsageMonitorService can read it directly without a channel round-trip.
  ///
  /// When a category's total usage exceeds its daily limit, ALL apps in that
  /// category are included in the exceeded list. Uncategorized apps (no
  /// categoryId) fall back to per-app isExceeded.
  Future<void> _syncBlockStateToNative(List<AppLimit> limits) async {
    try {
      final categories = LocalStorage.instance.getAppCategories(seed: false);

      // Build a set of all package names in exceeded categories.
      final exceededPkgs = <String>{};

      for (final cat in categories) {
        final usage = limits
            .where((l) => l.categoryId == cat.id)
            .fold<int>(0, (sum, l) => sum + l.usedMinutesToday);
        if (cat.dailyLimitMinutes > 0 && usage >= cat.dailyLimitMinutes) {
          // ALL apps in this category are blocked.
          for (final l in limits.where(
            (l) => l.categoryId == cat.id && l.isActive,
          )) {
            exceededPkgs.add(l.packageName);
          }
        }
      }

      // Also include uncategorized apps that are individually exceeded.
      for (final l in limits.where(
        (l) => l.isActive && l.isExceeded,
      )) {
        if (l.categoryId == null || l.categoryId!.isEmpty) {
          exceededPkgs.add(l.packageName);
        }
      }

      // Build the sync list.
      final exceeded =
          limits
              .where((l) => exceededPkgs.contains(l.packageName))
              .map(
                (l) => {
                  'packageName': l.packageName,
                  'appName': l.appName,
                  'usedMinutes': l.usedMinutesToday,
                  'limitMinutes': l.effectiveLimitMinutes,
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
    String? categoryId,
    String? iconBase64,
    int effectiveLimitMinutes = 0,
  }) async {
    final limit = AppLimit(
      packageName: packageName,
      appName: appName,
      categoryId: categoryId,
      iconBase64: iconBase64,
      effectiveLimitMinutes: effectiveLimitMinutes,
    );
    await LocalStorage.instance.upsertAppLimit(limit);
    _load();
    // Immediately sync with native and refresh usage so the UI updates.
    await _refreshUsageStats();
    await _syncBlockStateToNative(state.limits);
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

  // ── 3.6: Emergency extension — category-level ────────────────────────────

  /// Applies an emergency extension to the category of the given app.
  ///
  /// Increases the category's [dailyLimitMinutes] by
  /// [AppConstants.emergencyExtensionMinutes] and updates
  /// [effectiveLimitMinutes] on all apps in the category.
  /// Marks the requesting app's [emergencyExtUsedToday] as true.
  Future<bool> requestEmergencyExtension(String limitId) async {
    final idx = state.limits.indexWhere((l) => l.id == limitId);
    if (idx == -1) return false;
    final limit = state.limits[idx];
    if (limit.emergencyExtUsedToday) return false;

    final categoryId = limit.categoryId;

    if (categoryId == null || categoryId.isEmpty) {
      // Fallback: old per-app behaviour for uncategorised apps.
      final extended = limit.copyWith(
        emergencyExtUsedToday: true,
        effectiveLimitMinutes:
            limit.effectiveLimitMinutes + AppConstants.emergencyExtensionMinutes,
      );
      await LocalStorage.instance.upsertAppLimit(extended);
      _load();
      await _syncBlockStateToNative(state.limits);
      return true;
    }

    // Category-level extension.
    final categories = LocalStorage.instance.getAppCategories(seed: false);
    final catIdx = categories.indexWhere((c) => c.id == categoryId);
    if (catIdx == -1) return false;

    final cat = categories[catIdx];
    final updatedCat = cat.copyWith(
      dailyLimitMinutes:
          cat.dailyLimitMinutes + AppConstants.emergencyExtensionMinutes,
    );
    await LocalStorage.instance.upsertAppCategory(updatedCat);

    // Update all apps in this category with the new limit.
    final newLimits =
        state.limits.map((l) {
          if (l.categoryId == categoryId) {
            return l.copyWith(
              emergencyExtUsedToday:
                  l.id == limitId ? true : l.emergencyExtUsedToday,
              effectiveLimitMinutes: updatedCat.dailyLimitMinutes,
            );
          }
          return l;
        }).toList();

    await LocalStorage.instance.saveAppLimits(newLimits);
    _load();
    await _syncBlockStateToNative(state.limits);
    return true;
  }

  // ── Daily reset ──────────────────────────────────────────────────────────

  Future<void> resetDailyCounters() async {
    // Phase 1: restore categories that had an emergency extension.
    final categories = LocalStorage.instance.getAppCategories(seed: false);
    final limits = state.limits;
    final restoredCategories = <AppCategory>[];

    for (final cat in categories) {
      final hasEmergency = limits.any(
        (l) => l.categoryId == cat.id && l.emergencyExtUsedToday,
      );
      if (hasEmergency) {
        // Subtract the emergency extension from the category limit.
        restoredCategories.add(cat.copyWith(
          dailyLimitMinutes:
              (cat.dailyLimitMinutes - AppConstants.emergencyExtensionMinutes)
                  .clamp(1, 99999),
        ));
      } else {
        restoredCategories.add(cat);
      }
    }

    if (restoredCategories.any((c) => c.dailyLimitMinutes != categories
        .firstWhere((orig) => orig.id == c.id)
        .dailyLimitMinutes)) {
      await LocalStorage.instance.saveAppCategories(restoredCategories);
    }

    // Phase 2: reset app counters and sync effectiveLimitMinutes from categories.
    final catMap = {for (final c in restoredCategories) c.id: c.dailyLimitMinutes};
    final reset =
        limits
            .map((l) => l.copyWith(
              usedMinutesToday: 0,
              emergencyExtUsedToday: false,
              effectiveLimitMinutes:
                  l.categoryId != null && catMap.containsKey(l.categoryId)
                      ? catMap[l.categoryId]!
                      : l.effectiveLimitMinutes,
            ))
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
