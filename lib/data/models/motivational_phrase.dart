import 'package:uuid/uuid.dart';

class MotivationalPhrase {
  final String id;
  final String text;
  final String lang; // 'es' | 'en'
  final bool isDefault;
  bool isActive;
  final DateTime createdAt;

  MotivationalPhrase({
    String? id,
    required this.text,
    required this.lang,
    this.isDefault = false,
    this.isActive = true,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  MotivationalPhrase copyWith({String? text, bool? isActive}) =>
      MotivationalPhrase(
        id: id,
        text: text ?? this.text,
        lang: lang,
        isDefault: isDefault,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'lang': lang,
    'isDefault': isDefault,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MotivationalPhrase.fromJson(Map<String, dynamic> json) =>
      MotivationalPhrase(
        id: json['id'] as String,
        text: json['text'] as String,
        lang: json['lang'] as String? ?? 'es',
        isDefault: json['isDefault'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
