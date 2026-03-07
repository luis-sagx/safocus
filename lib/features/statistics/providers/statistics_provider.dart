import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/local_storage.dart';
import '../../../data/models/usage_stat.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/focus_score.dart' as sf;

class StatisticsState {
  final List<DailyUsageStat> weekStats; // last 7 days
  final List<BlockAttempt> recentAttempts;
  final int todayFocusScore;
  final int streakDays;
  final bool isLoading;

  const StatisticsState({
    this.weekStats = const [],
    this.recentAttempts = const [],
    this.todayFocusScore = 0,
    this.streakDays = 0,
    this.isLoading = false,
  });

  StatisticsState copyWith({
    List<DailyUsageStat>? weekStats,
    List<BlockAttempt>? recentAttempts,
    int? todayFocusScore,
    int? streakDays,
    bool? isLoading,
  }) => StatisticsState(
    weekStats: weekStats ?? this.weekStats,
    recentAttempts: recentAttempts ?? this.recentAttempts,
    todayFocusScore: todayFocusScore ?? this.todayFocusScore,
    streakDays: streakDays ?? this.streakDays,
    isLoading: isLoading ?? this.isLoading,
  );
}

class StatisticsNotifier extends StateNotifier<StatisticsState> {
  StatisticsNotifier() : super(const StatisticsState()) {
    refresh();
  }

  static const _blockedChannel = MethodChannel(
    AppConstants.channelBlockedAttempt,
  );

  void refresh() {
    final storage = LocalStorage.instance;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final allStats = storage.getUsageStats();
    final weekStats =
        allStats.where((s) => s.date.isAfter(weekAgo)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final attempts = storage.getBlockAttempts();
    final recentAttempts =
        attempts.where((a) => a.timestamp.isAfter(weekAgo)).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final focusScore = _computeTodayScore(weekStats, now);
    final streak = _computeStreak(allStats, now);

    state = StatisticsState(
      weekStats: weekStats,
      recentAttempts: recentAttempts,
      todayFocusScore: focusScore,
      streakDays: streak,
    );
  }

  /// Pull new blocked attempts recorded by the VPN service since last call.
  Future<void> syncBlockedAttempts() async {
    try {
      final raw = await _blockedChannel.invokeListMethod<Map>(
        'getAndClearAttempts',
      );
      if (raw == null || raw.isEmpty) return;

      final storage = LocalStorage.instance;
      for (final entry in raw) {
        final ts = entry['timestamp'] as int;
        final domain = entry['domain'] as String;
        await storage.addBlockAttempt(
          BlockAttempt(
            timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
            domain: domain,
          ),
        );
      }
      refresh();
    } on PlatformException {
      // Not on Android or VPN not running
    }
  }

  /// Clear all blocked attempts (manual reset — requires auth in UI).
  Future<void> clearBlockedAttempts() async {
    await LocalStorage.instance.clearBlockAttempts();
    refresh();
  }

  int _computeTodayScore(List<DailyUsageStat> stats, DateTime now) {
    final today = stats.where(
      (s) =>
          s.date.year == now.year &&
          s.date.month == now.month &&
          s.date.day == now.day,
    );
    if (today.isEmpty) return 0;
    final avgScore =
        today.map((s) => s.focusScore).reduce((a, b) => a + b) ~/ today.length;
    return avgScore.clamp(0, 100);
  }

  int _computeStreak(List<DailyUsageStat> allStats, DateTime now) {
    // Count consecutive days with score >= 50
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final day = now.subtract(Duration(days: i));
      final dayStats = allStats.where(
        (s) =>
            s.date.year == day.year &&
            s.date.month == day.month &&
            s.date.day == day.day,
      );
      if (dayStats.isEmpty) break;
      final avgScore =
          dayStats.map((s) => s.focusScore).reduce((a, b) => a + b) ~/
          dayStats.length;
      if (avgScore >= 50) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Aggregate usage by app name for the given stats.
  Map<String, int> aggregateByApp(List<DailyUsageStat> stats) {
    final map = <String, int>{};
    for (final s in stats) {
      map[s.appName] = (map[s.appName] ?? 0) + s.usageMinutes;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Record a new daily stat entry (called from app limits on usage update).
  Future<void> recordStat(DailyUsageStat stat) async {
    await LocalStorage.instance.addUsageStat(stat);
    refresh();
  }

  String focusLabel(int score) => sf.focusScoreLabel(score);
}

final statisticsProvider =
    StateNotifierProvider<StatisticsNotifier, StatisticsState>(
      (ref) => StatisticsNotifier(),
    );
