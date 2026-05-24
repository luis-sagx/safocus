# AGENTS.md — SaFocus

## Project type
Flutter app (Android) + Chrome extension (MV3). Flutter 3.7+, Dart 3.7+.

## Tech stack
- **State**: flutter_riverpod + riverpod_generator (codegen)
- **Navigation**: go_router
- **Storage**: flutter_secure_storage (PIN hash), shared_preferences (settings), LocalStorage (custom JSON)
- **Notifications**: flutter_local_notifications
- **Background**: workmanager (Android background tasks)
- **Auth**: local_auth (biometrics) + PIN
- **DNS blocking**: Android VPN TUN interface

## Developer commands
```bash
flutter pub get
flutter analyze          # lint + static analysis (analysis_options.yaml)
flutter test            # single test suite (test/widget_test.dart has no real tests)
flutter run             # run on device/emulator
flutter build apk --debug   # build debug APK
dart run build_runner build --delete-conflicting-outputs  # regenerate riverpod files
```

## Architecture
```
lib/
├── main.dart               # entrypoint, init order: storage → notifications → workmanager
├── navigation/
│   ├── app_router.dart      # go_router config, route constants in AppConstants
│   └── app_shell.dart       # shell scaffold
├── core/
│   ├── constants/           # AppConstants, blocked_sites, motivational_phrases
│   ├── theme/               # AppTheme, AppColors, AppTypography
│   └── utils/              # focus_score, date_utils
├── data/
│   ├── local/local_storage.dart  # JSON persistence (app limits, sites, stats)
│   └── models/             # usage_stat, motivational_phrase, app_limit, blocked_site
└── features/
    ├── auth/               # PIN + biometric auth screen + service
    ├── onboarding/
    ├── home/
    ├── blocking/          # VPN DNS blocking
    ├── app_limits/         # app usage limits + LimitMonitorService
    ├── notifications/      # motivational notification service + provider
    ├── statistics/
    └── settings/
```

## Riverpod codegen
`riverpod_generator` is used. Run `dart run build_runner build --delete-conflicting-outputs` after adding/changing `@riverpod` annotations. The generated files are NOT committed — they live in `.dart_tool/`.

## Testing
`test/widget_test.dart` is a placeholder (no real tests). Expand coverage before changing core logic.

## App localization
Spanish (es) and English (en). Supported locales hardcoded in `main.dart:138`. UI strings are not extracted to ARB files — inline strings in Spanish by default, wrap with `AppLocalizations` or use the language setting from `SettingsProvider`.

## Chrome extension
`chrome_extension/` is a standalone JS/HTML app (no Flutter). Load unpacked in Chrome at `chrome://extensions/` in dev mode. Uses `declarativeNetRequest` for blocking and `chrome.storage` for persistence.

## Native Android integration
`MethodChannel(AppConstants.channelBlockControl)` at `main.dart:78` receives `emergencyExtRequest` from native `BlockOverlayActivity`. The native Android project is in `android/`.

## Focus score formula
```
puntaje = vpnBonus + blockBonus + limitBonus
vpnBonus   = vpnActivo ? 40 : 0
blockBonus = min(30, intentosBloqueados × 3)
limitBonus = min(30, appsNoPasadas / totalApps × 30)
```

## Key files
- `lib/core/constants/app_constants.dart` — route names, channel names, storage keys
- `lib/data/local/local_storage.dart` — all persistence (getAppLimits, getBlockedSites, getStats, etc.)
- `lib/features/app_limits/services/limit_monitor_service.dart` — foreground + background monitoring
- `lib/features/notifications/services/notification_service.dart` — notification scheduling with timezone