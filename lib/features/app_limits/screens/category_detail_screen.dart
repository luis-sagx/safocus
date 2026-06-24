import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/app_category.dart';
import '../../../data/models/app_limit.dart';
import '../../auth/screens/auth_screen.dart';
import '../providers/app_limits_provider.dart';
import '../providers/categories_provider.dart';
import '../widgets/app_icon.dart';

// ── Icon helper ─────────────────────────────────────────────────────────────

IconData _catIcon(String? iconName) {
  switch (iconName) {
    case 'users':              return PhosphorIconsRegular.users;
    case 'gameController':      return PhosphorIconsRegular.gameController;
    case 'play':                return PhosphorIconsRegular.play;
    case 'newspaperClipping':   return PhosphorIconsRegular.newspaperClipping;
    case 'package':             return PhosphorIconsRegular.package;
    case 'chatCircleDots':      return PhosphorIconsRegular.chatCircleDots;
    case 'musicNotes':          return PhosphorIconsRegular.musicNotes;
    case 'camera':             return PhosphorIconsRegular.camera;
    case 'shoppingCart':       return PhosphorIconsRegular.shoppingCart;
    case 'basketball':         return PhosphorIconsRegular.basketball;
    case 'filmSlate':          return PhosphorIconsRegular.filmSlate;
    case 'bookOpen':           return PhosphorIconsRegular.bookOpen;
    case 'airplane':           return PhosphorIconsRegular.airplane;
    case 'hamburger':          return PhosphorIconsRegular.hamburger;
    case 'desktop':            return PhosphorIconsRegular.desktop;
    case 'paintBrush':         return PhosphorIconsRegular.paintBrush;
    case 'target':             return PhosphorIconsRegular.target;
    case 'barbell':            return PhosphorIconsRegular.barbell;
    case 'personSimpleTaiChi': return PhosphorIconsRegular.personSimpleTaiChi;
    case 'pencilSimple':       return PhosphorIconsRegular.pencilSimple;
    case 'lightbulb':          return PhosphorIconsRegular.lightbulb;
    case 'wrench':             return PhosphorIconsRegular.wrench;
    case 'heart':              return PhosphorIconsRegular.heart;
    case 'star':               return PhosphorIconsRegular.star;
    case 'fire':               return PhosphorIconsRegular.fire;
    case 'diamond':            return PhosphorIconsRegular.diamond;
    case 'rocket':             return PhosphorIconsRegular.rocket;
    case 'confetti':           return PhosphorIconsRegular.confetti;
    case 'globe':              return PhosphorIconsRegular.globe;
    case 'graduationCap':      return PhosphorIconsRegular.graduationCap;
    case 'briefcase':          return PhosphorIconsRegular.briefcase;
    case 'house':              return PhosphorIconsRegular.house;
    case 'folder':             return PhosphorIconsRegular.folder;
    default:                   return PhosphorIconsRegular.folder;
  }
}

// ── Cached app list (loaded once per session) ──────────────────────────────

class _CachedApp {
  final String name;
  final String packageName;
  final String iconBase64;
  const _CachedApp({
    required this.name,
    required this.packageName,
    this.iconBase64 = '',
  });
}

List<_CachedApp>? _cachedApps;
bool _appsLoading = false;

/// Pre-warms the app cache in the background.
/// Called from CategoryDetailScreen.initState so apps are ready by the time
/// the user presses "+".
Future<void> _warmAppCache() async {
  if (_cachedApps != null || _appsLoading) return;
  _appsLoading = true;
  try {
    const channel = MethodChannel('com.example.safocus/apps');
    final raw = await channel.invokeListMethod<Map>('getInstalledApps');
    _cachedApps = (raw ?? [])
        .map((m) => _CachedApp(
              name: m['name'] as String,
              packageName: m['package'] as String,
              iconBase64: (m['icon'] as String?) ?? '',
            ))
        .toList();
  } catch (_) {
    // Silently fail — the picker will retry when opened.
  } finally {
    _appsLoading = false;
  }
}

// ── Screen ──────────────────────────────────────────────────────────────────

class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({super.key, required this.categoryId});
  final String categoryId;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-warm the app cache so the "+" picker opens instantly.
    _warmAppCache();
  }

  @override
  Widget build(BuildContext context) {
    final limitsState = ref.watch(appLimitsProvider);
    final catsState = ref.watch(categoriesProvider);
    final limitsNotifier = ref.read(appLimitsProvider.notifier);
    final catsNotifier = ref.read(categoriesProvider.notifier);
    final strings = AppStrings.of(context);

    final cat = catsState.categories.cast<AppCategory?>().firstWhere(
      (c) => c?.id == widget.categoryId,
      orElse: () => null,
    );

    if (cat == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const Center(child: Text('Category not found')),
      );
    }

    final apps = limitsState.limits
        .where((l) => l.categoryId == widget.categoryId)
        .toList();
    final totalUsage = limitsState.categoryUsage[widget.categoryId] ?? 0;
    final isExceeded =
        limitsState.exceededCategoryIds.contains(widget.categoryId);
    final progress = cat.dailyLimitMinutes > 0
        ? (totalUsage / cat.dailyLimitMinutes).clamp(0.0, 1.0)
        : 0.0;
    final color = cat.flutterColor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_catIcon(cat.iconName), size: 22, color: color),
            const SizedBox(width: 8),
            Flexible(child: Text(cat.name,
              style: AppTypography.headlineMedium,
              overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise,
              color: AppColors.textSecondary, size: 20),
            tooltip: strings.refresh,
            onPressed: () => limitsNotifier.refresh(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
        children: [
          // ── Usage summary card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: isExceeded
                  ? Border.all(color: AppColors.error.withOpacity(0.4))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.appUsageLimits,
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '${formatMinutes(totalUsage)} / ${cat.dailyLimitMinutes > 0 ? formatMinutes(cat.dailyLimitMinutes) : '∞'}',
                            style: AppTypography.headlineMedium),
                        ],
                      ),
                    ),
                    if (isExceeded)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(strings.limitExceeded,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.error)),
                      ),
                  ],
                ),
                if (cat.dailyLimitMinutes > 0) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isExceeded ? AppColors.error
                            : progress > 0.8 ? AppColors.warning : color),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Time limit presets ──────────────────────────────────────────
          Text(strings.timeLimit, style: AppTypography.headlineSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: AppConstants.presetLimitMinutes.map((value) {
              final selected = value == cat.dailyLimitMinutes;
              return ChoiceChip(
                label: Text(strings.presetLabel(value)),
                selected: selected,
                selectedColor: AppColors.primary.withOpacity(0.25),
                onSelected: (_) async {
                  await catsNotifier.updateCategory(
                      cat.copyWith(dailyLimitMinutes: value));
                  // Propagate the new category limit to the apps' state and
                  // re-sync the native monitor so blocking uses the new value.
                  await limitsNotifier.reloadAndSync();
                },
                labelStyle: AppTypography.labelMedium.copyWith(
                  color: selected ? AppColors.primary : AppColors.textPrimary),
              );
            }).toList(),
          ),

          // ── Emergency extension ─────────────────────────────────────────
          if (isExceeded) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                ),
                onPressed: apps.isEmpty ? null : () async {
                  final ok = await limitsNotifier
                      .requestEmergencyExtension(apps.first.id);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(
                        strings.emergencyExtensionAlreadyUsed)),
                    );
                  }
                },
                icon: const Icon(PhosphorIconsRegular.clockCounterClockwise,
                    size: 16),
                label: Text(strings.emergencyExtensionLabel(
                    AppConstants.emergencyExtensionMinutes)),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Apps section ────────────────────────────────────────────────
          Row(
            children: [
              Text(strings.appsInCategory, style: AppTypography.headlineSmall),
              const Spacer(),
              Text('${apps.length}',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),

          if (apps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(strings.noLimitsConfigured,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary)),
              ),
            )
          else
            ...apps.map((app) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AppRow(
                limit: app,
                onDelete: () async {
                  await requireAuth(
                    context,
                    onAuthed: () => limitsNotifier.deleteLimit(app.id),
                  );
                },
              ),
            )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAppSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(PhosphorIconsRegular.plus,
            color: AppColors.textPrimary),
      ),
    );
  }

  // ── Add app sheet ─────────────────────────────────────────────────────────

  void _showAddAppSheet(BuildContext context) {
    final existing = ref.read(appLimitsProvider).limits
        .where((l) => l.categoryId == widget.categoryId)
        .map((l) => l.packageName)
        .toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AppPickerSheet(
        existingApps: existing,
        onAppSelected: (app) async {
          final cat = ref.read(categoriesProvider.notifier)
              .getById(widget.categoryId);
          await ref.read(appLimitsProvider.notifier).addLimit(
            packageName: app.packageName,
            appName: app.name,
            iconBase64: app.iconBase64,
            categoryId: widget.categoryId,
            effectiveLimitMinutes: cat?.dailyLimitMinutes ?? 60,
          );
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ── App row (no switch — category owns the toggle) ──────────────────────────

class _AppRow extends StatelessWidget {
  const _AppRow({required this.limit, required this.onDelete});
  final AppLimit limit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AppIcon(
            iconBase64: limit.iconBase64,
            appName: limit.appName,
            size: 40,
            borderRadius: 10,
            backgroundColor: AppColors.surfaceVariant,
            foregroundColor: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(limit.appName, style: AppTypography.labelLarge),
                const SizedBox(height: 2),
                Text(limit.packageName,
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatMinutes(limit.usedMinutesToday),
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary)),
          PopupMenuButton<String>(
            color: AppColors.surfaceVariant,
            onSelected: (v) {
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(PhosphorIconsRegular.trash,
                        color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Text(AppStrings.of(context).delete,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── App picker sheet ────────────────────────────────────────────────────────

class _AppPickerSheet extends StatefulWidget {
  const _AppPickerSheet({
    required this.existingApps,
    required this.onAppSelected,
  });
  final Set<String> existingApps;
  final void Function(_CachedApp app) onAppSelected;

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  List<_CachedApp> _all = [];
  List<_CachedApp> _filtered = [];
  bool _loading = true;
  String _error = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // If cache is already warm, use it immediately.
    if (_cachedApps != null) {
      _applyCache();
      return;
    }

    // Cache is being loaded by _warmAppCache() or hasn't started yet.
    // Wait for it to finish.
    await _warmAppCache();

    if (!mounted) return;

    if (_cachedApps != null) {
      _applyCache();
    } else {
      setState(() {
        _error = AppStrings.of(context).failedToLoadApps('');
        _loading = false;
      });
    }
  }

  void _applyCache() {
    _all = _cachedApps!;
    _filtered = _all
        .where((a) => !widget.existingApps.contains(a.packageName))
        .toList();
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((a) {
        if (widget.existingApps.contains(a.packageName)) return false;
        return a.name.toLowerCase().contains(q) ||
            a.packageName.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(strings.chooseAppToLimit,
                    style: AppTypography.headlineMedium),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(PhosphorIconsRegular.x,
                    color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: strings.searchApp,
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                  size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(PhosphorIconsRegular.x,
                          size: 16, color: AppColors.textSecondary),
                        onPressed: () => _searchCtrl.clear())
                    : null,
              ),
            ),
          ),
          // Content
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 48, height: 48,
                          child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 3),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppStrings.of(context).loadingApps,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.of(context).loadingAppsSubtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textDisabled),
                        ),
                      ],
                    ),
                  )
                : _error.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.error),
                            textAlign: TextAlign.center),
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(strings.noResults,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final app = _filtered[i];
                              return ListTile(
                                leading: AppIcon(
                                  iconBase64: app.iconBase64,
                                  appName: app.name,
                                  size: 40, borderRadius: 10,
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.15),
                                  foregroundColor: AppColors.primary,
                                ),
                                title: Text(app.name,
                                    style: AppTypography.bodyMedium),
                                subtitle: Text(app.packageName,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                                onTap: () => widget.onAppSelected(app),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
