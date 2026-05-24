import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/focus_score.dart';
import '../../../data/models/usage_stat.dart';
import '../../../navigation/app_router.dart';
import '../../app_limits/providers/app_limits_provider.dart';
import '../../blocking/providers/blocking_provider.dart';
import '../providers/statistics_provider.dart';

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
    final blockingState = ref.watch(blockingProvider);
    final hasUsagePermission = ref.watch(
      appLimitsProvider.select((s) => s.hasUsagePermission),
    );

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
                child: _UsageBarChart(
                  stats: state.weekStats,
                  hasUsagePermission: hasUsagePermission,
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 20)),

            // Enhanced blocked attempts section
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: _BlockedAttemptsSection(
                  attempts: state.recentAttempts,
                  activeSitesCount:
                      blockingState.sites.where((s) => s.isActive).length,
                ),
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
  const _UsageBarChart({required this.stats, required this.hasUsagePermission});
  final List<DailyUsageStat> stats;
  final bool hasUsagePermission;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
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
            const SizedBox(height: 12),
            Text(
              hasUsagePermission
                  ? 'Aún no hay historial suficiente para mostrar la gráfica. La app necesita registrar algunos días de uso.'
                  : 'Activa el permiso de “Uso de apps” para registrar minutos diarios y llenar esta gráfica.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (!hasUsagePermission) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go(AppRoutes.settings),
                  icon: const Icon(PhosphorIconsRegular.gear, size: 14),
                  label: const Text('Ir a ajustes'),
                ),
              ),
            ],
          ],
        ),
      );
    }

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
  const _BlockedAttemptsSection({
    required this.attempts,
    required this.activeSitesCount,
  });
  final List<BlockAttempt> attempts;
  final int activeSitesCount;

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

    // Most attempted domain this week
    final Map<String, int> domainCounts = {};
    for (final a in attempts) {
      final domain = _normalizeDomain(a.domain);
      domainCounts[domain] = (domainCounts[domain] ?? 0) + 1;
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
              Expanded(
                child: Text(
                  'Intentos bloqueados',
                  style: AppTypography.headlineSmall,
                ),
              ),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed:
                        () => context.push(AppRoutes.statisticsBlockedDetails),
                    icon: const Icon(
                      PhosphorIconsRegular.info,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Detalle',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
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
                label: 'Únicos',
                value: '${domainCounts.length}',
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: 'Activos',
                value: '$activeSitesCount',
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
                      maxLines: 2,
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

class BlockedAttemptsDetailScreen extends ConsumerWidget {
  const BlockedAttemptsDetailScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statisticsProvider);
    final blockingState = ref.watch(blockingProvider);
    final attempts = state.recentAttempts;
    final activeSitesCount =
        blockingState.sites.where((s) => s.isActive).length;
    final now = DateTime.now();

    final Map<String, int> domainCounts = {};
    final Map<String, String> rawSamples = {};
    for (final attempt in attempts) {
      final domain = _normalizeDomain(attempt.domain);
      domainCounts[domain] = (domainCounts[domain] ?? 0) + 1;
      rawSamples.putIfAbsent(domain, () => attempt.domain);
    }

    final sortedDomains =
        domainCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final todayCount =
        attempts.where((a) => _isSameDay(a.timestamp, now)).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle de bloqueos'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              'Esta pantalla separa los intentos bloqueados de los sitios configurados. ',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
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
                  value: '${attempts.length}',
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: 'Únicos',
                  value: '${domainCounts.length}',
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _StatPill(
              label: 'Sitios activos',
              value: '$activeSitesCount',
              color: AppColors.secondary,
            ),
            const SizedBox(height: 20),
            Text('Dominios más bloqueados', style: AppTypography.headlineSmall),
            const SizedBox(height: 12),
            if (sortedDomains.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Todavía no hay intentos bloqueados registrados.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...sortedDomains.take(20).map((entry) {
                final sample = rawSamples[entry.key] ?? entry.key;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SelectableText(
                              entry.key,
                              style: AppTypography.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${entry.value} veces',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      if (sample != entry.key) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Origen: $sample',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _normalizeDomain(String domain) {
  final host = domain.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final parts = host.split('.').where((part) => part.isNotEmpty).toList();
  if (parts.length <= 2) return host;

  final last = parts[parts.length - 1];
  final secondLast = parts[parts.length - 2];
  if (last.length == 2 && secondLast.length <= 3 && parts.length >= 3) {
    return parts.sublist(parts.length - 3).join('.');
  }
  return parts.sublist(parts.length - 2).join('.');
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
