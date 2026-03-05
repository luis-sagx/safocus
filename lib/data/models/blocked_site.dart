import 'package:uuid/uuid.dart';

/// A domain entry in the block list.
class BlockedSite {
  final String id;
  final String domain;
  final String? category;
  bool isActive;
  bool isDefault;
  final DateTime createdAt;

  BlockedSite({
    String? id,
    required this.domain,
    this.category,
    this.isActive = true,
    this.isDefault = false,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  BlockedSite copyWith({
    String? domain,
    String? category,
    bool? isActive,
    bool? isDefault,
  }) => BlockedSite(
    id: id,
    domain: domain ?? this.domain,
    category: category ?? this.category,
    isActive: isActive ?? this.isActive,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'domain': domain,
    'category': category,
    'isActive': isActive,
    'isDefault': isDefault,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BlockedSite.fromJson(Map<String, dynamic> json) => BlockedSite(
    id: json['id'] as String,
    domain: json['domain'] as String,
    category: json['category'] as String?,
    isActive: json['isActive'] as bool? ?? true,
    isDefault: json['isDefault'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
