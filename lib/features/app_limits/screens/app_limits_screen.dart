import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safocus/core/icons/phosphor_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/app_category.dart';
import '../../../data/models/app_limit.dart';
import '../../../navigation/app_router.dart';
import '../providers/app_limits_provider.dart';
import '../providers/categories_provider.dart';

// ── Category icon helper ────────────────────────────────────────────────────

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

/// Icons available when creating a custom category.
const _iconOptions = [
  'users', 'gameController', 'play', 'newspaperClipping', 'package',
  'chatCircleDots', 'musicNotes', 'camera', 'shoppingCart', 'basketball',
  'filmSlate', 'bookOpen', 'airplane', 'hamburger', 'desktop',
  'paintBrush', 'target', 'barbell', 'personSimpleTaiChi', 'pencilSimple',
  'lightbulb', 'wrench', 'heart', 'star', 'fire', 'diamond',
  'rocket', 'confetti', 'globe', 'graduationCap', 'briefcase', 'house',
  'folder',
];

// ── Screen ──────────────────────────────────────────────────────────────────

class AppLimitsScreen extends ConsumerWidget {
  const AppLimitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appLimitsProvider);
    final categoriesState = ref.watch(categoriesProvider);
    final strings = AppStrings.of(context);

    final grouped = _groupByCategory(state.limits, categoriesState.categories);
    final sortedCats = _sortCategoryList(categoriesState.categories);

    return Scaffold(
      backgroundColor: context.colors.background,
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
                          Text(strings.appLimitScreenTitle,
                              style: AppTypography.displayMedium),
                          const SizedBox(height: 4),
                          Text(
                            strings.appLimitScreenSubtitle,
                            style: AppTypography.bodyMedium.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showCreateCategoryDialog(context, ref),
                      icon: const Icon(
                        PhosphorIconsRegular.plusCircle,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      tooltip: strings.newCategory,
                    ),
                  ],
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 20)),

            // ── Category cards (show ALL categories, even empty ones) ────
            if (categoriesState.categories.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(strings: strings),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) {
                      final cat = sortedCats[index];
                      return _buildCategoryCard(
                        ctx,
                        cat,
                        grouped[cat.id] ?? [],
                        state,
                        strings,
                      );
                    },
                    childCount: sortedCats.length,
                  ),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  // ── Category card (tappable → detail screen) ──────────────────────────────

  Widget _buildCategoryCard(
    BuildContext context,
    AppCategory cat,
    List<AppLimit> apps,
    AppLimitsState state,
    AppStrings strings,
  ) {
    final totalUsage = state.categoryUsage[cat.id] ?? 0;
    final isExceeded = state.exceededCategoryIds.contains(cat.id);
    final progress = cat.dailyLimitMinutes > 0
        ? (totalUsage / cat.dailyLimitMinutes).clamp(0.0, 1.0)
        : 0.0;
    final color = cat.flutterColor;
    final Color progressColor = isExceeded
        ? AppColors.error
        : progress > 0.8
            ? AppColors.warning
            : color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => GoRouter.of(context).push(
            '${AppRoutes.categoryDetail}/${cat.id}',
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_categoryIcon(cat.iconName), size: 24, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat.name, style: AppTypography.labelLarge),
                          const SizedBox(height: 2),
                          Text(
                            '${formatMinutes(totalUsage)} / ${cat.dailyLimitMinutes > 0 ? formatMinutes(cat.dailyLimitMinutes) : '∞'}  ·  ${apps.length} apps',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    if (isExceeded)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
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
                      )
                    else
                      Icon(PhosphorIconsRegular.caretRight,
                          color: context.colors.textDisabled, size: 18),
                  ],
                ),
                if (cat.dailyLimitMinutes > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: context.colors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static Map<String, List<AppLimit>> _groupByCategory(
    List<AppLimit> limits,
    List<AppCategory> categories,
  ) {
    final uncatId = categories
        .where((c) => c.name == 'Uncategorized')
        .map((c) => c.id)
        .firstOrNull ??
        AppConstants.uncategorizedId;

    final map = <String, List<AppLimit>>{};
    for (final limit in limits) {
      final key = (limit.categoryId != null && limit.categoryId!.isNotEmpty)
          ? limit.categoryId!
          : uncatId;
      map.putIfAbsent(key, () => []).add(limit);
    }
    return map;
  }

  static List<AppCategory> _sortCategoryList(List<AppCategory> cats) {
    final sorted = List<AppCategory>.from(cats);
    sorted.sort((a, b) {
      final aUncat = a.name == 'Uncategorized';
      final bUncat = b.name == 'Uncategorized';
      if (aUncat && !bUncat) return 1;
      if (!aUncat && bUncat) return -1;
      return a.name.compareTo(b.name);
    });
    return sorted;
  }
}

// ── Create category dialog ──────────────────────────────────────────────────

Future<void> _showCreateCategoryDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final strings = AppStrings.of(context);
  final catsNotifier = ref.read(categoriesProvider.notifier);
  final nameCtrl = TextEditingController();
  String? iconName = 'folder';
  String color = '#6C63FF';
  int limit = 60;

  final cat = await showDialog<AppCategory>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
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
                      if (picked != null) setDialogState(() => iconName = picked);
                    },
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(_categoryIcon(iconName),
                          size: 28, color: AppColors.primary),
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
                Text(strings.categoryColor, style: AppTypography.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: const [
                    '#6C63FF', '#2196F3', '#4CAF50', '#FF5722',
                    '#E91E63', '#FFB347', '#00BCD4', '#9E9E9E',
                    '#795548', '#607D8B',
                  ].map((preset) {
                    final selected = preset == color;
                    return GestureDetector(
                      onTap: () => setDialogState(() => color = preset),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Color(int.parse(
                            'FF${preset.replaceFirst('#', '')}', radix: 16)),
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: context.colors.textPrimary, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text(strings.timeLimit, style: AppTypography.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: AppConstants.presetLimitMinutes.map((value) {
                    final selected = value == limit;
                    return ChoiceChip(
                      label: Text(strings.presetLabel(value)),
                      selected: selected,
                      selectedColor: AppColors.primary.withOpacity(0.25),
                      onSelected: (_) => setDialogState(() => limit = value),
                      labelStyle: AppTypography.labelMedium.copyWith(
                        color: selected ? AppColors.primary : context.colors.textPrimary),
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
    ),
  );

  if (cat != null && context.mounted) {
    await catsNotifier.addCategory(
      name: cat.name,
      color: cat.color,
      emoji: '',
      iconName: cat.iconName,
      dailyLimitMinutes: cat.dailyLimitMinutes,
    );
  }
}

// ── Simple icon picker ──────────────────────────────────────────────────────

Future<String?> _showIconPicker(BuildContext context, String? current) async {
  String? selected;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text(AppStrings.of(context).chooseEmoji,
            style: AppTypography.headlineSmall),
          content: SizedBox(
            width: 300,
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: _iconOptions.map((name) {
                final isSelected = name == (selected ?? current);
                return GestureDetector(
                  onTap: () => setDialogState(() => selected = name),
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.2)
                          : context.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        _categoryIcon(name),
                        size: 24,
                        color: isSelected ? AppColors.primary : context.colors.textSecondary,
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
              child: Text(AppStrings.of(context).cancel,
                style: AppTypography.labelMedium),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected ?? current ?? 'folder'),
              child: Text(AppStrings.of(context).save),
            ),
          ],
        );
      },
    ),
  );

  return selected;
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(PhosphorIconsFill.clockCountdown,
                color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 24),
            Text(strings.noLimitsConfigured, style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text(strings.addAppsToLimitSubtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: context.colors.textSecondary),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
