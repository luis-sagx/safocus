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
import '../../../navigation/app_router.dart';
import '../../auth/screens/auth_screen.dart';
import '../providers/app_limits_provider.dart';
import '../providers/categories_provider.dart';
import '../widgets/app_icon.dart';

// ── Category icon helper ────────────────────────────────────────────────────

/// Maps an [AppCategory.iconName] to a Phosphor icon, falling back to a
/// folder icon when unrecognised.
IconData _categoryIcon(String? iconName) {
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

class AppLimitsScreen extends ConsumerWidget {
  const AppLimitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appLimitsProvider);
    final categoriesState = ref.watch(categoriesProvider);
    final notifier = ref.read(appLimitsProvider.notifier);
    final strings = AppStrings.of(context);

    // ── Group limits by categoryId ──────────────────────────────────────
    final grouped = _groupByCategory(state.limits, categoriesState.categories);
    final sortedCategories = _sortCategories(grouped.keys.toList());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.appLimitScreenTitle, style: AppTypography.displayMedium),
                          const SizedBox(height: 4),
                          Text(
                            strings.appLimitScreenSubtitle,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push(AppRoutes.categoryManagement),
                      icon: const Icon(
                        PhosphorIconsRegular.folders,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                      tooltip: strings.manageCategories,
                    ),
                  ],
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 20)),

            // ── List grouped by category ────────────────────────────────
            if (state.limits.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(
                  onAdd: () => _showAddDialog(context, notifier, ref),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) {
                      return _buildCategorySection(
                        ctx,
                        index,
                        sortedCategories,
                        grouped,
                        state,
                        strings,
                        notifier,
                        categoriesState,
                        ref,
                      );
                    },
                    childCount: sortedCategories.length,
                  ),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, notifier, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(
          PhosphorIconsRegular.plus,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // ── Category section ─────────────────────────────────────────────────────

  Widget _buildCategorySection(
    BuildContext context,
    int index,
    List<String> sortedIds,
    Map<String, List<AppLimit>> grouped,
    AppLimitsState state,
    AppStrings strings,
    AppLimitsNotifier notifier,
    CategoriesState categoriesState,
    WidgetRef ref,
  ) {
    final catId = sortedIds[index];
    final apps = grouped[catId]!;
    final cat = categoriesState.categories.firstWhere(
      (c) => c.id == catId,
      orElse: () => AppCategory(
        id: catId,
        name: strings.uncategorized,
        color: '#9E9E9E',
        emoji: '📦',
        dailyLimitMinutes: 0,
        isPredefined: false,
      ),
    );

    final totalUsage = state.categoryUsage[catId] ?? 0;
    final isExceeded = state.exceededCategoryIds.contains(catId);
    final progress = cat.dailyLimitMinutes > 0
        ? (totalUsage / cat.dailyLimitMinutes).clamp(0.0, 1.0)
        : 0.0;
    final color = cat.flutterColor;
    final Color progressColor =
        isExceeded
            ? AppColors.error
            : progress > 0.8
            ? AppColors.warning
            : color;

    return Padding(
      padding: EdgeInsets.only(
        bottom: index < sortedIds.length - 1 ? 16 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: isExceeded
                  ? Border.all(color: AppColors.error.withOpacity(0.4))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon (Phosphor or emoji fallback)
                    Icon(
                      _categoryIcon(cat.iconName),
                      size: 22,
                      color: color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat.name, style: AppTypography.labelLarge),
                          const SizedBox(height: 2),
                          Text(
                            '${formatMinutes(totalUsage)} / ${cat.dailyLimitMinutes > 0 ? formatMinutes(cat.dailyLimitMinutes) : '∞'}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    // Exceeded badge
                    if (isExceeded)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          strings.limitExceeded,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    // Add app button
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        onPressed: () => _showAddDialogForCategory(
                          context,
                          notifier,
                          ref,
                          cat.id,
                        ),
                        icon: const Icon(
                          PhosphorIconsRegular.plusCircle,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: strings.addAppToCategory,
                      ),
                    ),
                  ],
                ),
                if (cat.dailyLimitMinutes > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── App cards (indented) ─────────────────────────────────────
          const SizedBox(height: 8),
          ...apps.map(
            (limit) => Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: _AppLimitCard(
                limit: limit,
                onToggle: () async => notifier.toggleLimit(limit),
                onDelete: () async {
                  await requireAuth(
                    context,
                    onAuthed: () => notifier.deleteLimit(limit.id),
                  );
                },
                onEmergency: () async {
                  return notifier.requestEmergencyExtension(limit.id);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add dialog ────────────────────────────────────────────────────────────

  Future<void> _showAddDialog(
    BuildContext context,
    AppLimitsNotifier notifier,
    WidgetRef ref, {
    String? initialCategoryId,
  }) async {
    final categoriesState = ref.read(categoriesProvider);
    final catsNotifier = ref.read(categoriesProvider.notifier);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _AddLimitSheet(
            categories: categoriesState.categories,
            categoriesNotifier: catsNotifier,
            initialCategoryId: initialCategoryId,
            onAdd:
                ({
                  required packageName,
                  required appName,
                  iconBase64,
                  required categoryId,
                  required effectiveLimitMinutes,
                }) => notifier.addLimit(
                  packageName: packageName,
                  appName: appName,
                  iconBase64: iconBase64,
                  categoryId: categoryId,
                  effectiveLimitMinutes: effectiveLimitMinutes,
                ),
          ),
    );
  }

  /// Opens the add flow directly with [categoryId] pre‑selected, skipping
  /// the category‑picker step.
  Future<void> _showAddDialogForCategory(
    BuildContext context,
    AppLimitsNotifier notifier,
    WidgetRef ref,
    String categoryId,
  ) async {
    await _showAddDialog(context, notifier, ref, initialCategoryId: categoryId);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Groups limits by categoryId. Limits without categoryId go under
  /// the fallback "Uncategorized" id.
  static Map<String, List<AppLimit>> _groupByCategory(
    List<AppLimit> limits,
    List<AppCategory> categories,
  ) {
    final uncatId = categories
        .where((c) => c.name == 'Uncategorized')
        .map((c) => c.id)
        .firstOrNull ?? AppConstants.uncategorizedId;

    final map = <String, List<AppLimit>>{};
    for (final limit in limits) {
      final key = (limit.categoryId != null && limit.categoryId!.isNotEmpty)
          ? limit.categoryId!
          : uncatId;
      map.putIfAbsent(key, () => []).add(limit);
    }
    return map;
  }

  /// Sorts category IDs so that Uncategorized is last, others by name.
  static List<String> _sortCategories(List<String> ids) {
    ids.sort((a, b) {
      final aUncat = a == AppConstants.uncategorizedId;
      final bUncat = b == AppConstants.uncategorizedId;
      if (aUncat && !bUncat) return 1;
      if (!aUncat && bUncat) return -1;
      return a.compareTo(b);
    });
    return ids;
  }
}

// ── App Limit Card ─────────────────────────────────────────────────────────

class _AppLimitCard extends StatelessWidget {
  const _AppLimitCard({
    required this.limit,
    required this.onToggle,
    required this.onDelete,
    required this.onEmergency,
  });
  final AppLimit limit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Future<bool> Function() onEmergency;

  @override
  Widget build(BuildContext context) {
    final exceeded = limit.isExceeded;
    final progress = limit.progressRatio;
    final Color trackColor =
        exceeded
            ? AppColors.error
            : progress > 0.8
            ? AppColors.warning
            : AppColors.primary;
    final strings = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            exceeded
                ? Border.all(color: AppColors.error.withOpacity(0.3))
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with AppIcon
          Row(
            children: [
              AppIcon(
                iconBase64: limit.iconBase64,
                appName: limit.appName,
                size: 36,
                borderRadius: 8,
                backgroundColor: AppColors.surfaceVariant,
                foregroundColor: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(limit.appName, style: AppTypography.labelLarge),
                    Text(
                      limit.packageName,
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Individual app progress (only if not part of a category with limit)
              if (limit.effectiveLimitMinutes > 0) ...[
                Text(
                  '${formatMinutes(limit.usedMinutesToday)} / ${formatMinutes(limit.effectiveLimitMinutes)}',
                  style: AppTypography.caption,
                ),
              ],
              Switch(
                value: limit.isActive,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.primary,
              ),
              PopupMenuButton<String>(
                color: AppColors.surfaceVariant,
                onSelected: (v) async {
                  if (v == 'delete') onDelete();
                },
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.trash,
                              color: AppColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.delete,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),

          // Progress bar (only for per-app limits)
          if (limit.effectiveLimitMinutes > 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatMinutes(limit.usedMinutesToday)} ${strings.used}',
                  style: AppTypography.labelMedium,
                ),
                Text(
                  '${strings.limitPrefix} ${formatMinutes(limit.effectiveLimitMinutes)}',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(trackColor),
              ),
            ),
          ],

          // Emergency extension
          if (exceeded && !limit.emergencyExtUsedToday) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                ),
                onPressed: () async {
                  final ok = await onEmergency();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.emergencyExtensionAlreadyUsed)),
                    );
                  }
                },
                icon: const Icon(
                  PhosphorIconsRegular.clockCounterClockwise,
                  size: 16,
                ),
                label: Text(
                  strings.emergencyExtensionLabel(AppConstants.emergencyExtensionMinutes),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsFill.clockCountdown,
                color: AppColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(strings.noLimitsConfigured, style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text(
              strings.addAppsToLimitSubtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(PhosphorIconsRegular.plus, size: 18),
              label: Text(strings.addApplication),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add limit sheet ────────────────────────────────────────────────────────

typedef _OnAdd =
    Future<void> Function({
      required String packageName,
      required String appName,
      String? iconBase64,
      required String categoryId,
      required int effectiveLimitMinutes,
    });

// Model for an installed app entry
class _InstalledApp {
  final String name;
  final String packageName;
  final String iconBase64;
  const _InstalledApp({
    required this.name,
    required this.packageName,
    this.iconBase64 = '',
  });
}

class _AddLimitSheet extends StatefulWidget {
  const _AddLimitSheet({
    required this.onAdd,
    required this.categories,
    required this.categoriesNotifier,
    this.initialCategoryId,
  });
  final _OnAdd onAdd;
  final List<AppCategory> categories;
  final CategoriesNotifier categoriesNotifier;
  final String? initialCategoryId;

  @override
  State<_AddLimitSheet> createState() => _AddLimitSheetState();
}

class _AddLimitSheetState extends State<_AddLimitSheet> {
  static const _appsChannel = MethodChannel('com.example.safocus/apps');

  // Step tracking: 0 = category picker, 1 = app picker, 2 = confirm
  int _step = 0;

  // Category selection
  AppCategory? _selectedCategory;

  // App picker
  List<_InstalledApp>? _allApps;
  List<_InstalledApp> _filtered = [];
  bool _loadingApps = true;
  String _errorMsg = '';
  final _searchCtrl = TextEditingController();

  // Confirm
  _InstalledApp? _selectedApp;
  int _selectedMinutes = 60;
  bool _saving = false;

  static const _presetValues = [15, 30, 60, 120];

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchCtrl.addListener(_filter);

    // If a category is pre‑selected, skip straight to the app picker.
    if (widget.initialCategoryId != null) {
      final cat = widget.categories.cast<AppCategory?>().firstWhere(
        (c) => c?.id == widget.initialCategoryId,
        orElse: () => null,
      );
      if (cat != null) {
        _selectedCategory = cat;
        _selectedMinutes = cat.dailyLimitMinutes;
        _step = 1;
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    try {
      final raw = await _appsChannel.invokeListMethod<Map>('getInstalledApps');
      final apps =
          (raw ?? [])
              .map(
                (m) => _InstalledApp(
                  name: m['name'] as String,
                  packageName: m['package'] as String,
                  iconBase64: (m['icon'] as String?) ?? '',
                ),
              )
              .toList();
      if (mounted) {
        setState(() {
          _allApps = apps;
          _filtered = apps;
          _loadingApps = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = AppStrings.of(context).failedToLoadApps(e.toString());
          _loadingApps = false;
        });
      }
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered =
          (_allApps ?? [])
              .where(
                (a) =>
                    a.name.toLowerCase().contains(q) ||
                    a.packageName.toLowerCase().contains(q),
              )
              .toList();
    });
  }

  void _selectCategory(AppCategory cat) {
    setState(() {
      _selectedCategory = cat;
      _selectedMinutes = cat.dailyLimitMinutes;
    });
    // If existing category with a limit > 0, skip to app picker.
    if (cat.dailyLimitMinutes > 0) {
      setState(() => _step = 1);
    } else {
      // Uncategorized (no limit) — go to time picker second
      setState(() => _step = 1);
    }
  }

  void _selectApp(_InstalledApp app) {
    setState(() => _selectedApp = app);
    if (_selectedCategory != null && _selectedCategory!.dailyLimitMinutes > 0) {
      // Existing category with limit — skip confirmation, save directly.
      _save();
    } else {
      setState(() => _step = 2);
    }
  }

  void _back() {
    if (_step == 2) {
      setState(() => _step = 1); // back to app picker
    } else if (_step == 1) {
      setState(() {
        _step = 0;
        _selectedCategory = null;
      });
    }
  }

  Future<void> _save() async {
    final app = _selectedApp;
    final cat = _selectedCategory;
    if (app == null || cat == null) return;

    // Check if the app is already in another category.
    final existingCat = widget.categoriesNotifier.getCategoryForApp(app.packageName);
    if (existingCat != null && existingCat.id != cat.id && mounted) {
      final strings = AppStrings.of(context);
      final move = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(strings.appAlreadyInCategory(app.name, existingCat.name),
            style: AppTypography.headlineSmall),
          content: Text(strings.moveAppToThisCategory,
            style: AppTypography.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.keepInCurrent),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(strings.moveApp),
            ),
          ],
        ),
      );
      if (move != true) return;
    }

    setState(() => _saving = true);
    await widget.onAdd(
      packageName: app.packageName,
      appName: app.name,
      iconBase64: app.iconBase64,
      categoryId: cat.id,
      effectiveLimitMinutes:
          cat.dailyLimitMinutes > 0 ? cat.dailyLimitMinutes : _selectedMinutes,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildCategoryPicker();
      case 1:
        return _buildAppPicker();
      case 2:
        return _buildTimeStep();
      default:
        return _buildCategoryPicker();
    }
  }

  // ── Step 0: Category picker ──────────────────────────────────────────────

  Widget _buildCategoryPicker() {
    final strings = AppStrings.of(context);
    // Filter out Uncategorized from the picker.
    final selectableCats = widget.categories
        .where((c) => c.name != 'Uncategorized')
        .toList();

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.selectCategory, style: AppTypography.headlineMedium),
                      Text(
                        strings.chooseCategory,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    PhosphorIconsRegular.x,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Category grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.0,
              ),
              itemCount: selectableCats.length + 1, // +1 for "New category"
              itemBuilder: (_, i) {
                if (i == selectableCats.length) {
                  // "New category" button
                  return _buildNewCategoryTile(strings);
                }
                final cat = selectableCats[i];
                return _buildCategoryTile(cat);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(AppCategory cat) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectCategory(cat),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    _categoryIcon(cat.iconName),
                    size: 20,
                    color: cat.flutterColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cat.name,
                      style: AppTypography.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (cat.dailyLimitMinutes > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${formatMinutes(cat.dailyLimitMinutes)} ${AppStrings.of(context).minutesLabel}',
                  style: AppTypography.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewCategoryTile(AppStrings strings) {
    return Material(
      color: AppColors.surfaceVariant.withOpacity(0.4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showNewCategoryDialog(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                PhosphorIconsRegular.plusCircle,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                strings.newCategory,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── New category dialog ──────────────────────────────────────────────────

  Future<void> _showNewCategoryDialog() async {
    final strings = AppStrings.of(context);
    final nameCtrl = TextEditingController();
    String? iconName = 'folder';
    String color = '#6C63FF';
    int limit = 60;

    final cat = await showDialog<AppCategory>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(strings.newCategory, style: AppTypography.headlineSmall),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon picker
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await _showIconPicker(ctx, iconName);
                          if (picked != null) {
                            setDialogState(() => iconName = picked);
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Icon(
                              _categoryIcon(iconName),
                              size: 28,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: strings.categoryName,
                        hintText: strings.categoryNameHint,
                      ),
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(strings.timeLimit, style: AppTypography.labelMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          _presetValues.map((value) {
                            final selected = value == limit;
                            return ChoiceChip(
                              label: Text(strings.presetLabel(value)),
                              selected: selected,
                              selectedColor: AppColors.primary.withOpacity(0.25),
                              onSelected: (_) => setDialogState(() => limit = value),
                              labelStyle: AppTypography.labelMedium.copyWith(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(strings.cancel, style: AppTypography.labelMedium),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final cat = AppCategory(
                      name: name,
                      color: color,
                      emoji: '',
                      iconName: iconName,
                      dailyLimitMinutes: limit,
                      isPredefined: false,
                    );
                    Navigator.pop(ctx, cat);
                  },
                  child: Text(strings.create),
                ),
              ],
            );
          },
        );
      },
    );

    if (cat != null && mounted) {
      await widget.categoriesNotifier.addCategory(
        name: cat.name,
        color: cat.color,
        emoji: '',
        iconName: cat.iconName,
        dailyLimitMinutes: cat.dailyLimitMinutes,
      );
      // Re-read categories and proceed.
      setState(() {
        _selectedCategory = cat;
        _selectedMinutes = cat.dailyLimitMinutes;
        _step = 1;
      });
    }
  }

  // ── Step 1: App picker ───────────────────────────────────────────────────

  Widget _buildAppPicker() {
    final strings = AppStrings.of(context);
    final cat = _selectedCategory!;
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
                IconButton(
                  onPressed: _back,
                  icon: const Icon(
                    PhosphorIconsRegular.arrowLeft,
                    color: AppColors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.selectApp, style: AppTypography.headlineMedium),
                      Row(
                        children: [
                          Icon(
                            _categoryIcon(cat.iconName),
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cat.name,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    PhosphorIconsRegular.x,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: strings.searchApp,
                prefixIcon: const Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            PhosphorIconsRegular.x,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => _searchCtrl.clear(),
                        )
                        : null,
              ),
            ),
          ),
          // App list
          Expanded(
            child:
                _loadingApps
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                    : _errorMsg.isNotEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMsg,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : _filtered.isEmpty
                    ? Center(
                      child: Text(
                        strings.noResults,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
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
                            size: 40,
                            borderRadius: 10,
                            backgroundColor: AppColors.primary.withOpacity(0.15),
                            foregroundColor: AppColors.primary,
                          ),
                          title: Text(
                            app.name,
                            style: AppTypography.bodyMedium,
                          ),
                          subtitle: Text(
                            app.packageName,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () => _selectApp(app),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Time limit picker (only for new categories / uncategorized) ──

  Widget _buildTimeStep() {
    final app = _selectedApp!;
    final cat = _selectedCategory!;
    final strings = AppStrings.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back + title
          Row(
            children: [
              IconButton(
                onPressed: _back,
                icon: const Icon(
                  PhosphorIconsRegular.arrowLeft,
                  color: AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(strings.timeLimit, style: AppTypography.headlineMedium),
            ],
          ),
          const SizedBox(height: 16),
          // Selected category + app chips
          Row(
            children: [
              // Category chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cat.flutterColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _categoryIcon(cat.iconName),
                      size: 14,
                      color: cat.flutterColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cat.name,
                      style: AppTypography.labelSmall.copyWith(
                        color: cat.flutterColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // App chip
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      AppIcon(
                        iconBase64: app.iconBase64,
                        appName: app.name,
                        size: 24,
                        borderRadius: 6,
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        foregroundColor: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          app.name,
                          style: AppTypography.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(strings.maximumDailyTime, style: AppTypography.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _presetValues.map((value) {
                  final selected = value == _selectedMinutes;
                  return ChoiceChip(
                    label: Text(strings.presetLabel(value)),
                    selected: selected,
                    selectedColor: AppColors.primary.withOpacity(0.25),
                    onSelected: (_) => setState(() => _selectedMinutes = value),
                    labelStyle: AppTypography.labelMedium.copyWith(
                      color:
                          selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child:
                  _saving
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(strings.saveLimit),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Icon picker (replaces emoji picker) ──────────────────────────────────

  static const _iconNames = [
    'users', 'gameController', 'play', 'newspaperClipping', 'package',
    'chatCircleDots', 'musicNotes', 'camera', 'shoppingCart', 'basketball',
    'filmSlate', 'bookOpen', 'airplane', 'hamburger', 'desktop',
    'paintBrush', 'target', 'barbell', 'personSimpleTaiChi', 'pencilSimple',
    'lightbulb', 'wrench', 'heart', 'star', 'fire', 'diamond',
    'rocket', 'confetti', 'globe', 'graduationCap', 'briefcase', 'house',
  ];

  Future<String?> _showIconPicker(BuildContext context, String? current) async {
    String? selected;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(
                AppStrings.of(context).chooseEmoji,
                style: AppTypography.headlineSmall,
              ),
              content: SizedBox(
                width: 300,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _iconNames.map((name) {
                        final isSelected = name == (selected ?? current);
                        return GestureDetector(
                          onTap: () => setDialogState(() => selected = name),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.2)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: AppColors.primary, width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Icon(
                                _categoryIcon(name),
                                size: 24,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    AppStrings.of(context).cancel,
                    style: AppTypography.labelMedium,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, selected ?? current ?? 'folder'),
                  child: Text(AppStrings.of(context).save),
                ),
              ],
            );
          },
        );
      },
    );

    return selected;
  }
}
