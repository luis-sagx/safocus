import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/duo_pair.dart';

class DuoNotifier extends StateNotifier<DuoPair?> {
  DuoNotifier() : super(null) {
    _load();
  }

  static const _kKey = 'duo_pair_json';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      var pair = DuoPair.fromJson(map);
      // Reset daily check-in if last check-in was not today
      final now = DateTime.now();
      if (pair.myCheckedInToday && pair.lastBothCheckedIn != null) {
        final last = pair.lastBothCheckedIn!;
        final isToday =
            last.year == now.year &&
            last.month == now.month &&
            last.day == now.day;
        if (!isToday) {
          pair = pair.copyWith(myCheckedInToday: false);
        }
      }
      state = pair;
    } catch (_) {}
  }

  Future<void> _save(DuoPair pair) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, json.encode(pair.toJson()));
    state = pair;
  }

  /// Generate a new duo with a random invite code.
  Future<void> createDuo() async {
    const uuid = Uuid();
    final part1 = uuid.v4().substring(0, 3).toUpperCase();
    final part2 = uuid.v4().replaceAll('-', '').substring(0, 3).toUpperCase();
    final code = '$part1-$part2';
    final pair = DuoPair(myCode: code);
    await _save(pair);
  }

  Future<void> setPartner({
    required String partnerCode,
    String? partnerName,
  }) async {
    if (state == null) await createDuo();
    final pair = state!.copyWith(
      partnerCode: partnerCode.trim().toUpperCase(),
      partnerName:
          partnerName?.trim().isNotEmpty == true ? partnerName!.trim() : null,
    );
    await _save(pair);
  }

  Future<void> checkInToday() async {
    if (state == null) return;
    final now = DateTime.now();
    // In local-only mode: mark self as checked in; treat as "both" done.
    final newStreak = state!.sharedStreakDays + 1;
    final pair = state!.copyWith(
      myCheckedInToday: true,
      sharedStreakDays: newStreak,
      lastBothCheckedIn: now,
    );
    await _save(pair);
  }

  Future<void> leaveDuo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
    state = null;
  }
}

final duoProvider = StateNotifierProvider<DuoNotifier, DuoPair?>(
  (ref) => DuoNotifier(),
);
