import 'package:uuid/uuid.dart';

/// User‑defined limit for a specific application.
class AppLimit {
  final String id;
  final String packageName; // e.g. com.instagram.android
  final String appName; // display name
  final int dailyLimitMinutes; // 0 = unlimited
  int usedMinutesToday;
  bool isActive;
  bool emergencyExtUsedToday;
  final DateTime createdAt;

  AppLimit({
    String? id,
    required this.packageName,
    required this.appName,
    required this.dailyLimitMinutes,
    this.usedMinutesToday = 0,
    this.isActive = true,
    this.emergencyExtUsedToday = false,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Remaining minutes today (never negative).
  int get remainingMinutes =>
      (dailyLimitMinutes - usedMinutesToday).clamp(0, dailyLimitMinutes);

  /// Whether the limit has been exceeded.
  bool get isExceeded =>
      dailyLimitMinutes > 0 && usedMinutesToday >= dailyLimitMinutes;

  /// Progress ratio 0–1.
  double get progressRatio => dailyLimitMinutes > 0
      ? (usedMinutesToday / dailyLimitMinutes).clamp(0.0, 1.0)
      : 0.0;

  AppLimit copyWith({
    String? appName,
    int? dailyLimitMinutes,
    int? usedMinutesToday,
    bool? isActive,
    bool? emergencyExtUsedToday,
  }) => AppLimit(
    id: id,
    packageName: packageName,
    appName: appName ?? this.appName,
    dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
    usedMinutesToday: usedMinutesToday ?? this.usedMinutesToday,
    isActive: isActive ?? this.isActive,
    emergencyExtUsedToday: emergencyExtUsedToday ?? this.emergencyExtUsedToday,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'packageName': packageName,
    'appName': appName,
    'dailyLimitMinutes': dailyLimitMinutes,
    'usedMinutesToday': usedMinutesToday,
    'isActive': isActive,
    'emergencyExtUsedToday': emergencyExtUsedToday,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppLimit.fromJson(Map<String, dynamic> json) => AppLimit(
    id: json['id'] as String,
    packageName: json['packageName'] as String,
    appName: json['appName'] as String,
    dailyLimitMinutes: json['dailyLimitMinutes'] as int,
    usedMinutesToday: json['usedMinutesToday'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    emergencyExtUsedToday: json['emergencyExtUsedToday'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
