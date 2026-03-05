import 'package:uuid/uuid.dart';

/// Aggregated usage data for a specific day.
class DailyUsageStat {
  final String id;
  final DateTime date;
  final String packageName;
  final String appName;
  final int usageMinutes;
  final int blockedAttempts;
  final int focusScore;

  DailyUsageStat({
    String? id,
    required this.date,
    required this.packageName,
    required this.appName,
    required this.usageMinutes,
    this.blockedAttempts = 0,
    this.focusScore = 0,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'packageName': packageName,
    'appName': appName,
    'usageMinutes': usageMinutes,
    'blockedAttempts': blockedAttempts,
    'focusScore': focusScore,
  };

  factory DailyUsageStat.fromJson(Map<String, dynamic> json) => DailyUsageStat(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    packageName: json['packageName'] as String,
    appName: json['appName'] as String,
    usageMinutes: json['usageMinutes'] as int? ?? 0,
    blockedAttempts: json['blockedAttempts'] as int? ?? 0,
    focusScore: json['focusScore'] as int? ?? 0,
  );
}

/// Single blocked‑site access attempt log entry.
class BlockAttempt {
  final String id;
  final DateTime timestamp;
  final String domain;

  BlockAttempt({String? id, required this.timestamp, required this.domain})
    : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'domain': domain,
  };

  factory BlockAttempt.fromJson(Map<String, dynamic> json) => BlockAttempt(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    domain: json['domain'] as String,
  );
}
