import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/app_category.dart';
import '../../auth/screens/auth_screen.dart';
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

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoriesProvider);
    final notifier = ref.read(categoriesProvider.notifier);
    final strings = AppStrings.of(context);

    // Show Uncategorized separately at the bottom.
    final uncat = state.uncategorized;
    final regularCats = state.categories.where((c) => c.id != uncat?.id).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(strings.manageCategories, style: AppTypography.headlineMedium),
      ),
      body: state.categories.isEmpty
          ? _EmptyCategoriesState(strings: strings)
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Regular categories
                ...regularCats.map(
                  (cat) => _CategoryTile(
                    category: cat,
                    strings: strings,
                    onEdit: () => _showEditDialog(context, notifier, cat, strings),
                    onDelete:
                        cat.isPredefined
                            ? null
                            : () async {
                              await requireAuth(
                                context,
                                onAuthed: () => notifier.deleteCategory(cat.id),
                              );
                            },
                  ),
                ),
                // Uncategorized
                if (uncat != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      strings.uncategorized,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _CategoryTile(
                    category: uncat,
                    strings: strings,
                    onEdit: () => _showEditDialog(context, notifier, uncat, strings),
                    onDelete: null, // Uncategorized is undeletable
                  ),
                ],
                const SizedBox(height: 100),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, notifier, strings),
        backgroundColor: AppColors.primary,
        child: const Icon(
          PhosphorIconsRegular.plus,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ── Category Tile ───────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.strings,
    required this.onEdit,
    this.onDelete,
  });

  final AppCategory category;
  final AppStrings strings;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = category.flutterColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      _categoryIcon(category.iconName),
                      size: 22,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Name + limit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name, style: AppTypography.labelLarge),
                      const SizedBox(height: 2),
                      Text(
                        category.dailyLimitMinutes > 0
                            ? '${strings.limitPrefix} ${formatMinutes(category.dailyLimitMinutes)}'
                            : '${strings.noCategory} · 0m',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                // Color indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                // Predefined badge
                if (category.isPredefined)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      strings.predefined,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontSize: 9,
                      ),
                    ),
                  ),
                // Delete button (only for non-predefined)
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      PhosphorIconsRegular.trash,
                      size: 18,
                      color: AppColors.error,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyCategoriesState extends StatelessWidget {
  const _EmptyCategoriesState({required this.strings});
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
              child: const Icon(
                PhosphorIconsFill.folders,
                color: AppColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(strings.noCategoriesYet, style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text(
              strings.addCategorySubtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create / Edit dialog ────────────────────────────────────────────────────

Future<void> _showCreateDialog(
  BuildContext context,
  CategoriesNotifier notifier,
  AppStrings strings,
) async {
  await _showCategoryForm(
    context: context,
    notifier: notifier,
    strings: strings,
    title: strings.newCategoryTitle,
    onSave:
        ({required name, required color, required iconName, required limit}) =>
            notifier.addCategory(
              name: name,
              color: color,
              emoji: '',
              iconName: iconName,
              dailyLimitMinutes: limit,
            ),
  );
}

Future<void> _showEditDialog(
  BuildContext context,
  CategoriesNotifier notifier,
  AppCategory category,
  AppStrings strings,
) async {
  await _showCategoryForm(
    context: context,
    notifier: notifier,
    strings: strings,
    title: strings.editCategory,
    initialName: category.name,
    initialColor: category.color,
    initialIconName: category.iconName,
    initialLimit: category.dailyLimitMinutes,
    isPredefined: category.isPredefined,
    onSave:
        ({required name, required color, required iconName, required limit}) =>
            notifier.updateCategory(
              category.copyWith(
                name: name,
                color: color,
                iconName: iconName,
                dailyLimitMinutes: limit,
              ),
            ),
  );
}

Future<void> _showCategoryForm({
  required BuildContext context,
  required CategoriesNotifier notifier,
  required AppStrings strings,
  required String title,
  required Future<void> Function({
    required String name,
    required String color,
    required String iconName,
    required int limit,
  })
  onSave,
  String initialName = '',
  String initialColor = '#6C63FF',
  String? initialIconName,
  int initialLimit = 60,
  bool isPredefined = false,
}) async {
  final nameCtrl = TextEditingController(text: initialName);
  String color = initialColor;
  String? iconName = initialIconName ?? 'folder';
  int limit = initialLimit;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(title, style: AppTypography.headlineSmall),
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
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Icon(
                            _categoryIcon(iconName),
                            size: 32,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: strings.categoryName,
                      hintText: strings.categoryNameHint,
                    ),
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  // Color presets
                  Text(strings.categoryColor, style: AppTypography.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colorPresets.map((preset) {
                      final selected = preset == color;
                      return GestureDetector(
                        onTap: () => setDialogState(() => color = preset),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse('FF${preset.replaceFirst('#', '')}', radix: 16),
                            ),
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: AppColors.textPrimary, width: 2)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // Time limit
                  Text(strings.timeLimit, style: AppTypography.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        AppConstants.presetLimitMinutes.map((value) {
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
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  await onSave(name: name, color: color, iconName: iconName ?? 'folder', limit: limit);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(strings.save),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<String?> _showIconPicker(BuildContext context, String? current) async {
  final iconNames = [
    'users', 'gameController', 'play', 'newspaperClipping', 'package',
    'chatCircleDots', 'musicNotes', 'camera', 'shoppingCart', 'basketball',
    'filmSlate', 'bookOpen', 'airplane', 'hamburger', 'desktop',
    'paintBrush', 'target', 'barbell', 'personSimpleTaiChi', 'pencilSimple',
    'lightbulb', 'wrench', 'heart', 'star', 'fire', 'diamond',
    'rocket', 'confetti', 'globe', 'graduationCap', 'briefcase', 'house',
  ];

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
                    iconNames.map((name) {
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

const _colorPresets = [
  '#6C63FF', // indigo (default)
  '#2196F3', // blue
  '#4CAF50', // green
  '#FF5722', // deep orange
  '#E91E63', // pink
  '#FFB347', // amber
  '#00BCD4', // cyan
  '#9E9E9E', // grey
  '#795548', // brown
  '#607D8B', // blue grey
];
