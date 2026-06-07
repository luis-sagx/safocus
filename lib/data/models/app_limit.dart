import 'package:uuid/uuid.dart';

/// User‑defined limit for a specific application.
class AppLimit {
  final String id;
  final String packageName; // e.g. com.instagram.android
  final String appName; // display name
  final String? categoryId; // null before migration
  final String? iconBase64; // PNG icon as base64, null when unavailable
  final int effectiveLimitMinutes; // resolved from category, 0 = unlimited
  int usedMinutesToday;
  bool isActive;
  bool emergencyExtUsedToday;
  final DateTime createdAt;

  AppLimit({
    String? id,
    required this.packageName,
    required this.appName,
    this.categoryId,
    this.iconBase64,
    this.effectiveLimitMinutes = 0,
    this.usedMinutesToday = 0,
    this.isActive = true,
    this.emergencyExtUsedToday = false,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Remaining minutes today (never negative).
  int get remainingMinutes =>
      (effectiveLimitMinutes - usedMinutesToday)
          .clamp(0, effectiveLimitMinutes);

  /// Whether the limit has been exceeded.
  bool get isExceeded =>
      effectiveLimitMinutes > 0 && usedMinutesToday >= effectiveLimitMinutes;

  /// Progress ratio 0–1.
  double get progressRatio => effectiveLimitMinutes > 0
      ? (usedMinutesToday / effectiveLimitMinutes).clamp(0.0, 1.0)
      : 0.0;

  AppLimit copyWith({
    String? appName,
    String? categoryId,
    String? iconBase64,
    int? effectiveLimitMinutes,
    int? usedMinutesToday,
    bool? isActive,
    bool? emergencyExtUsedToday,
  }) => AppLimit(
    id: id,
    packageName: packageName,
    appName: appName ?? this.appName,
    categoryId: categoryId ?? this.categoryId,
    iconBase64: iconBase64 ?? this.iconBase64,
    effectiveLimitMinutes:
        effectiveLimitMinutes ?? this.effectiveLimitMinutes,
    usedMinutesToday: usedMinutesToday ?? this.usedMinutesToday,
    isActive: isActive ?? this.isActive,
    emergencyExtUsedToday: emergencyExtUsedToday ?? this.emergencyExtUsedToday,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'packageName': packageName,
    'appName': appName,
    'categoryId': categoryId,
    'iconBase64': iconBase64,
    'effectiveLimitMinutes': effectiveLimitMinutes,
    'usedMinutesToday': usedMinutesToday,
    'isActive': isActive,
    'emergencyExtUsedToday': emergencyExtUsedToday,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppLimit.fromJson(Map<String, dynamic> json) => AppLimit(
    id: json['id'] as String,
    packageName: json['packageName'] as String,
    appName: json['appName'] as String,
    categoryId: json['categoryId'] as String?,
    iconBase64: json['iconBase64'] as String?,
    effectiveLimitMinutes: json['effectiveLimitMinutes'] as int? ?? 0,
    usedMinutesToday: json['usedMinutesToday'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    emergencyExtUsedToday: json['emergencyExtUsedToday'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
