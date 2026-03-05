import 'package:flutter/material.dart';

extension SfDateUtils on DateTime {
  /// Returns midnight for this date.
  DateTime get midnight => DateTime(year, month, day);

  /// Whether two DateTimes share the same calendar day.
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Friendly label: "Today", "Yesterday" or locale‑aware short date.
  String dayLabel(BuildContext context) {
    final now = DateTime.now();
    if (isSameDay(now)) return 'Hoy';
    if (isSameDay(now.subtract(const Duration(days: 1)))) return 'Ayer';
    return '$day/${month.toString().padLeft(2, '0')}/$year';
  }
}

/// Format [minutes] as "Xh Ym" or "Ym" when under an hour.
String formatMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Format seconds similarly.
String formatSeconds(int seconds) => formatMinutes(seconds ~/ 60);

/// Current hour as 0–23.
int get currentHour => DateTime.now().hour;

/// Minutes elapsed since [startOfDay] (midnight).
int minutesSinceMidnight() {
  final now = DateTime.now();
  return now.hour * 60 + now.minute;
}
