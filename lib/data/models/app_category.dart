import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// A limit category that groups apps under a shared daily time budget.
class AppCategory {
  final String id;
  final String name; // display name (Spanish or English)
  final String color; // hex string e.g. "#FF5722"
  final String emoji;
  final String? iconName; // Phosphor icon identifier (e.g. "users", "gameController")
  final int dailyLimitMinutes;
  final bool isPredefined;
  final DateTime createdAt;

  AppCategory({
    String? id,
    required this.name,
    required this.color,
    required this.emoji,
    this.iconName,
    required this.dailyLimitMinutes,
    this.isPredefined = false,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Parses the hex color string into a Flutter [Color].
  Color get flutterColor {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  AppCategory copyWith({
    String? name,
    String? color,
    String? emoji,
    String? iconName,
    int? dailyLimitMinutes,
    bool? isPredefined,
  }) => AppCategory(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    emoji: emoji ?? this.emoji,
    iconName: iconName ?? this.iconName,
    dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
    isPredefined: isPredefined ?? this.isPredefined,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'emoji': emoji,
    if (iconName != null) 'iconName': iconName,
    'dailyLimitMinutes': dailyLimitMinutes,
    'isPredefined': isPredefined,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppCategory.fromJson(Map<String, dynamic> json) => AppCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String,
    emoji: json['emoji'] as String? ?? '📦',
    iconName: json['iconName'] as String?,
    dailyLimitMinutes: json['dailyLimitMinutes'] as int,
    isPredefined: json['isPredefined'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
