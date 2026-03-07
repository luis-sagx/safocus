import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/focus_score.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/local/local_storage.dart';
import '../../../data/models/usage_stat.dart';
import '../providers/statistics_provider.dart';
import '../../auth/screens/auth_screen.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    // Sync blocked attempts from VPN service when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(statisticsProvider.notifier).syncBlockedAttempts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statisticsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estadísticas',
                          style: AppTypography.displayMedium,
                        ),
                        Text(
                          'Últimos 7 días',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        PhosphorIconsRegular.arrowClockwise,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () async {
                        await ref
                            .read(statisticsProvider.notifier)
                            .syncBlockedAttempts();
                        ref.read(statisticsProvider.notifier).refresh();
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 20)),

            // Focus score + streak row
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(child: _ScoreCard(score: state.todayFocusScore)),
                    const SizedBox(width: 12),
                    Expanded(child: _StreakCard(days: state.streakDays)),
                  ],
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 20)),

            // Usage bar chart
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: _UsageBarChart(stats: state.weekStats),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 20)),

            // Enhanced blocked attempts section
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: _BlockedAttemptsSection(attempts: state.recentAttempts),
              ),
            ),

            // Per-app usage
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Text('Uso por app', style: AppTypography.headlineSmall),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              sliver: SliverToBoxAdapter(
                child: _AppUsageList(
                  aggregated: ref
                      .read(statisticsProvider.notifier)
                      .aggregateByApp(state.weekStats),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Score card ─────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = focusScoreColor(score);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Puntaje hoy', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: AppTypography.displayLarge.copyWith(color: color),
          ),
          Text(
            focusScoreLabel(score),
            style: AppTypography.bodySmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Racha', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          Text(
            '$days',
            style: AppTypography.displayLarge.copyWith(
              color: AppColors.warning,
            ),
          ),
          Text(
            days == 1 ? 'día' : 'días',
            style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
          ),
        ],
      ),
    );
  }
}

// ── Bar chart ──────────────────────────────────────────────────────────────

class _UsageBarChart extends StatelessWidget {
  const _UsageBarChart({required this.stats});
  final List<DailyUsageStat> stats;

  @override
  Widget build(BuildContext context) {
    // Aggregate minutes per day label
    final Map<String, int> daily = {};
    for (final s in stats) {
      final key = '${s.date.day}/${s.date.month}';
      daily[key] = (daily[key] ?? 0) + s.usageMinutes;
    }

    // Fill last 7 days
    final days = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      final key = '${d.day}/${d.month}';
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (daily[key] ?? 0).toDouble(),
            width: 16,
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    final labels = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      return '${d.day}/${d.month}';
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Minutos de uso diario', style: AppTypography.headlineSmall),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: days,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine:
                      (_) => const FlLine(
                        color: AppColors.divider,
                        strokeWidth: 1,
                      ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget:
                          (value, _) => Text(
                            labels[value.toInt()],
                            style: AppTypography.labelSmall,
                          ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem:
                        (group, _, rod, __) => BarTooltipItem(
                          '${rod.toY.toInt()} min',
                          AppTypography.labelMedium,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Enhanced blocked attempts section ─────────────────────────────────────

class _BlockedAttemptsSection extends ConsumerWidget {
  const _BlockedAttemptsSection({required this.attempts});
  final List<BlockAttempt> attempts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    // Aggregate per day (last 7 days)
    final Map<int, int> dailyCounts = {}; // dayOffset -> count (0=today)
    for (final a in attempts) {
      final diff = now.difference(a.timestamp).inDays;
      if (diff >= 0 && diff < 7) {
        dailyCounts[diff] = (dailyCounts[diff] ?? 0) + 1;
      }
    }

    // Today / week totals
    final todayCount = dailyCounts[0] ?? 0;
    final weekCount = attempts.length;

    // Monthly count (using all stored attempts)
    final allAttempts = LocalStorage.instance.getBlockAttempts();
    final monthAgo = now.subtract(const Duration(days: 30));
    final monthCount =
        allAttempts.where((a) => a.timestamp.isAfter(monthAgo)).length;

    // Most attempted domain this week
    final Map<String, int> domainCounts = {};
    for (final a in attempts) {
      domainCounts[a.domain] = (domainCounts[a.domain] ?? 0) + 1;
    }
    String? topDomain;
    int topCount = 0;
    domainCounts.forEach((domain, count) {
      if (count > topCount) {
        topCount = count;
        topDomain = domain;
      }
    });

    // Build bar chart data
    final bars = List.generate(7, (i) {
      final dayOffset = 6 - i; // i=0 = 6 days ago, i=6 = today
      final count = dailyCounts[dayOffset] ?? 0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            width: 16,
            color: AppColors.error,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    final barLabels = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.day}/${d.month}';
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sitios bloqueados', style: AppTypography.headlineSmall),
              TextButton.icon(
                onPressed: () async {
                  await requireAuth(
                    context,
                    onAuthed: () async {
                      await ref
                          .read(statisticsProvider.notifier)
                          .clearBlockedAttempts();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Historial de bloqueos eliminado.'),
                          ),
                        );
                      }
                    },
                  );
                },
                icon: const Icon(
                  PhosphorIconsRegular.trash,
                  size: 14,
                  color: AppColors.error,
                ),
                label: Text(
                  'Limpiar',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Summary tiles
          Row(
            children: [
              _StatPill(
                label: 'Hoy',
                value: '$todayCount',
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: 'Semana',
                value: '$weekCount',
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: '30 días',
                value: '$monthCount',
                color: AppColors.primary,
              ),
            ],
          ),

          if (topDomain != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.trendUp,
                    color: AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Más intentado: $topDomain ($topCount veces)',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Bar chart — per day this week
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: bars,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine:
                      (_) => const FlLine(
                        color: AppColors.divider,
                        strokeWidth: 1,
                      ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget:
                          (value, _) => Text(
                            barLabels[value.toInt()],
                            style: AppTypography.labelSmall,
                          ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem:
                        (group, _, rod, __) => BarTooltipItem(
                          '${rod.toY.toInt()}',
                          AppTypography.labelMedium.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.headlineMedium.copyWith(color: color),
            ),
            Text(label, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }
}

// ── App usage list ─────────────────────────────────────────────────────────

class _AppUsageList extends StatelessWidget {
  const _AppUsageList({required this.aggregated});
  final Map<String, int> aggregated;

  @override
  Widget build(BuildContext context) {
    if (aggregated.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'Sin datos de uso registrados aún.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final maxMinutes =
        aggregated.values.reduce((a, b) => a > b ? a : b).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children:
            aggregated.entries.take(8).map((entry) {
              final ratio = entry.value / maxMinutes;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key, style: AppTypography.bodyMedium),
                        Text(
                          formatMinutes(entry.value),
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}
