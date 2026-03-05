import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/focus_score.dart';
import '../../../core/utils/date_utils.dart';
import '../../../features/blocking/providers/blocking_provider.dart';
import '../../../features/app_limits/providers/app_limits_provider.dart';
import '../../../features/statistics/providers/statistics_provider.dart';
import '../../../navigation/app_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocking = ref.watch(blockingProvider);
    final limits = ref.watch(appLimitsProvider);
    final stats = ref.watch(statisticsProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App bar ─────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          'lib/assets/logo.png',
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          now.dayLabel(context),
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => context.go(AppRoutes.settings),
                      icon: const Icon(
                        PhosphorIconsRegular.gear,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 24)),

            // ── Focus score card ────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: _FocusScoreCard(score: stats.todayFocusScore),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 16)),

            // ── Permission warning banner ───────────────────────────────
            if (!limits.allPermissionsGranted)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: _PermissionBanner(state: limits),
                ),
              ),

            if (!limits.allPermissionsGranted)
              const SliverPadding(padding: EdgeInsets.only(top: 12)),

            // ── Status row ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _StatusCard(
                        icon:
                            blocking.vpnActive
                                ? PhosphorIconsFill.shieldCheck
                                : PhosphorIconsFill.shieldWarning,
                        label: 'Bloqueo Web',
                        value: blocking.vpnActive ? 'Activo' : 'Inactivo',
                        accent:
                            blocking.vpnActive
                                ? AppColors.secondary
                                : AppColors.textSecondary,
                        onTap: () => context.go(AppRoutes.blocking),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusCard(
                        icon: PhosphorIconsFill.clockCountdown,
                        label: 'Límites',
                        value:
                            '${limits.limits.where((l) => l.isActive).length} activos',
                        accent: AppColors.primary,
                        onTap: () => context.go(AppRoutes.appLimits),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 16)),

            // ── Streak + attempts ───────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        icon: PhosphorIconsFill.flame,
                        label: 'Racha',
                        value: '${stats.streakDays} días',
                        accent: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        icon: PhosphorIconsFill.prohibit,
                        label: 'Bloq hoy',
                        value:
                            stats.recentAttempts
                                .where(
                                  (a) => a.timestamp.isAfter(
                                    DateTime.now().subtract(
                                      const Duration(days: 1),
                                    ),
                                  ),
                                )
                                .length
                                .toString(),
                        accent: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 24)),

            // ── App limits list ─────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Límites de uso', style: AppTypography.headlineSmall),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.appLimits),
                      child: Text(
                        'Ver todos',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              sliver:
                  limits.limits.isEmpty
                      ? SliverToBoxAdapter(
                        child: _EmptyLimits(
                          onAdd: () => context.go(AppRoutes.appLimits),
                        ),
                      )
                      : SliverList.separated(
                        itemCount: limits.limits.length.clamp(0, 4),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder:
                            (_, i) => _AppLimitRow(limit: limits.limits[i]),
                      ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────

class _FocusScoreCard extends StatelessWidget {
  const _FocusScoreCard({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = focusScoreColor(score);
    final label = focusScoreLabel(score);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Text(
                  '$score',
                  style: AppTypography.headlineMedium.copyWith(color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Puntaje de Enfoque', style: AppTypography.labelMedium),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTypography.headlineSmall.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  'Basado en tus límites y bloqueos activos hoy',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 28),
            const SizedBox(height: 12),
            Text(label, style: AppTypography.labelMedium),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.headlineSmall.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.labelMedium),
              const SizedBox(height: 2),
              Text(value, style: AppTypography.headlineSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppLimitRow extends StatelessWidget {
  const _AppLimitRow({required this.limit});
  final dynamic limit; // AppLimit

  @override
  Widget build(BuildContext context) {
    final progress = limit.progressRatio as double;
    final remaining = limit.remainingMinutes as int;
    final exceeded = limit.isExceeded as bool;
    final color =
        exceeded
            ? AppColors.error
            : progress > 0.8
            ? AppColors.warning
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(limit.appName as String, style: AppTypography.labelLarge),
              Text(
                exceeded
                    ? 'Límite superado'
                    : '${formatMinutes(remaining)} restantes',
                style: AppTypography.labelMedium.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLimits extends StatelessWidget {
  const _EmptyLimits({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          const Icon(
            PhosphorIconsRegular.clockCountdown,
            color: AppColors.textSecondary,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text('Sin límites configurados', style: AppTypography.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Agrega límites diarios a tus apps distractoras',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAdd, child: const Text('Agregar límite')),
        ],
      ),
    );
  }
}

// ── Permission warning banner ────────────────────────────────────────────────

class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner({required this.state});
  final AppLimitsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appLimitsProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsFill.shieldWarning,
                color: AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El bloqueo de apps no está activo',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Faltan permisos para que SaFocus bloquee apps al superar el límite diario.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!state.hasUsagePermission)
                _BannerButton(
                  label: 'Uso de apps',
                  onTap: () async {
                    await notifier.openUsageSettings();
                    await Future.delayed(const Duration(seconds: 1));
                    await notifier.refreshPermissions();
                  },
                ),
              if (!state.hasUsagePermission && !state.hasOverlayPermission)
                const SizedBox(width: 8),
              if (!state.hasOverlayPermission)
                _BannerButton(
                  label: 'Superponer ventanas',
                  onTap: () async {
                    await notifier.openOverlaySettings();
                    await Future.delayed(const Duration(seconds: 1));
                    await notifier.refreshPermissions();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
