abstract class AppConstants {
  // ── App meta ─────────────────────────────────────────────────────────────
  static const String appName = 'SaFocus';
  static const String appVersion = '1.0.0';

  // ── Hive box names ────────────────────────────────────────────────────────
  static const String boxSettings = 'settings';
  static const String boxBlockedSites = 'blocked_sites';
  static const String boxAppLimits = 'app_limits';
  static const String boxPhrases = 'phrases';
  static const String boxUsageStats = 'usage_stats';
  static const String boxFocusSessions = 'focus_sessions';

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyPinEnabled = 'pin_enabled';
  static const String keyPin =
      'pin_hash'; // legacy key, now unused (hash stored in SecureStorage)
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyVpnEnabled = 'vpn_enabled';
  static const String keyQuietStart = 'quiet_start';
  static const String keyQuietEnd = 'quiet_end';
  static const String keyEmergencyExtUsed = 'emergency_ext_used';
  static const String keyEmergencyExtDate = 'emergency_ext_date';
  static const String keyBlockAttemptsResetDate = 'block_attempts_reset_date';

  // ── Notification IDs ─────────────────────────────────────────────────────
  static const int notifMotivationalId = 1000;
  static const int notifAppLimitId = 2000;
  static const int notifLimitWarningBase = 3000; // +index for per-app
  static const int notifCountdownBase = 4000; // +index for per-app countdown
  static const String notifChannelMotivational = 'safocus_motivational';
  static const String notifChannelAlerts = 'safocus_alerts';
  static const String notifChannelLimitWarning = 'safocus_limit_warning';
  static const String notifChannelCountdown = 'safocus_countdown';

  // ── Platform channels ─────────────────────────────────────────────────────
  static const String channelVpn = 'com.example.safocus/vpn';
  static const String channelUsage = 'com.example.safocus/usage';
  static const String channelBlockedAttempt =
      'com.example.safocus/blocked_attempt';
  static const String channelBlockControl = 'com.example.safocus/block_control';

  // ── WorkManager task names ────────────────────────────────────────────────
  static const String taskLimitMonitor = 'safocus_limit_monitor';

  // ── Deep link routes ──────────────────────────────────────────────────────
  static const String routeAppLimits = '/app-limits';
  static const String routeBlockOverlay = '/block-overlay';

  // ── SharedPrefs keys ─────────────────────────────────────────────────────
  static const String keyLastDailyReset = 'last_daily_reset_date';

  // ── Timezone ──────────────────────────────────────────────────────────────
  /// UTC offset for America/Guayaquil (Ecuador) is fixed at -5h (no DST).
  static const Duration guayaquilOffset = Duration(hours: -5);

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const int emergencyExtensionMinutes = 5;
  static const List<int> presetLimitMinutes = [15, 30, 60, 120];
  static const int focusScoreMax = 100;
  static const int limitWarningMinutes = 10; // notify when < 10 min remain
}
