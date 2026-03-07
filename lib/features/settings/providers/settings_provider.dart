import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/local_storage.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/services/auth_service.dart';

enum AppThemeMode { dark, light, system }

class SettingsState {
  final AppThemeMode themeMode;
  final String language; // 'es' | 'en'
  final bool pinEnabled;
  final bool biometricEnabled;
  final int quietStartHour; // 0–23
  final int quietEndHour;

  const SettingsState({
    this.themeMode = AppThemeMode.dark,
    this.language = 'es',
    this.pinEnabled = false,
    this.biometricEnabled = false,
    this.quietStartHour = 22,
    this.quietEndHour = 7,
  });

  ThemeMode get flutterThemeMode => switch (themeMode) {
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.system => ThemeMode.system,
  };

  SettingsState copyWith({
    AppThemeMode? themeMode,
    String? language,
    bool? pinEnabled,
    bool? biometricEnabled,
    int? quietStartHour,
    int? quietEndHour,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    language: language ?? this.language,
    pinEnabled: pinEnabled ?? this.pinEnabled,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    quietStartHour: quietStartHour ?? this.quietStartHour,
    quietEndHour: quietEndHour ?? this.quietEndHour,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  void _load() {
    final s = LocalStorage.instance;
    final themeStr = s.getString(AppConstants.keyThemeMode) ?? 'dark';
    final theme = AppThemeMode.values.firstWhere(
      (e) => e.name == themeStr,
      orElse: () => AppThemeMode.dark,
    );
    state = SettingsState(
      themeMode: theme,
      language: s.getString(AppConstants.keyLanguage) ?? 'es',
      pinEnabled: s.getBool(AppConstants.keyPinEnabled),
      biometricEnabled: s.getBool(AppConstants.keyBiometricEnabled),
      quietStartHour: s.getInt(AppConstants.keyQuietStart, defaultValue: 22),
      quietEndHour: s.getInt(AppConstants.keyQuietEnd, defaultValue: 7),
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await LocalStorage.instance.setString(AppConstants.keyThemeMode, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setLanguage(String lang) async {
    await LocalStorage.instance.setString(AppConstants.keyLanguage, lang);
    state = state.copyWith(language: lang);
  }

  Future<void> togglePin(bool enabled, {String? pin}) async {
    if (enabled && pin != null) {
      await AuthService.instance.setPin(pin);
    } else if (!enabled) {
      await AuthService.instance.removePin();
    }
    state = state.copyWith(pinEnabled: enabled);
  }

  Future<void> toggleBiometric(bool enabled) async {
    if (enabled) {
      await AuthService.instance.enableBiometric();
    } else {
      await AuthService.instance.disableBiometric();
    }
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> setQuietHours(int start, int end) async {
    final s = LocalStorage.instance;
    await s.setInt(AppConstants.keyQuietStart, start);
    await s.setInt(AppConstants.keyQuietEnd, end);
    state = state.copyWith(quietStartHour: start, quietEndHour: end);
  }

  Future<void> resetAllData() async {
    await LocalStorage.instance.clear();
    state = const SettingsState();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
