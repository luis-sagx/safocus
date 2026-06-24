import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/local/local_storage.dart';
import '../../../data/models/app_category.dart';

class CategoriesState {
  final List<AppCategory> categories;
  final bool isLoading;

  const CategoriesState({
    this.categories = const [],
    this.isLoading = false,
  });

  CategoriesState copyWith({
    List<AppCategory>? categories,
    bool? isLoading,
  }) => CategoriesState(
    categories: categories ?? this.categories,
    isLoading: isLoading ?? this.isLoading,
  );

  /// Returns the "Uncategorized" category (predefined or custom) or null.
  AppCategory? get uncategorized {
    try {
      return categories.firstWhere((c) => c.name == 'Uncategorized');
    } catch (_) {
      return null;
    }
  }
}

class CategoriesNotifier extends StateNotifier<CategoriesState> {
  CategoriesNotifier() : super(const CategoriesState()) {
    _load();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  void _load() {
    final categories = LocalStorage.instance.getAppCategories();
    state = state.copyWith(categories: categories);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> addCategory({
    required String name,
    required String color,
    required String emoji,
    String? iconName,
    required int dailyLimitMinutes,
  }) async {
    final category = AppCategory(
      name: name,
      color: color,
      emoji: emoji,
      iconName: iconName,
      dailyLimitMinutes: dailyLimitMinutes,
    );
    await LocalStorage.instance.upsertAppCategory(category);
    _load();
  }

  /// Updates a category and propagates its [dailyLimitMinutes] to the
  /// effectiveLimitMinutes of every app assigned to it.
  ///
  /// Without this propagation the apps keep their old limit, so lowering a
  /// category limit (e.g. 60 → 30) would still report the old remaining time
  /// and block too late.
  Future<void> updateCategory(AppCategory category) async {
    await LocalStorage.instance.upsertAppCategory(category);

    final limits = LocalStorage.instance.getAppLimits();
    final affected = limits.any(
      (l) =>
          l.categoryId == category.id &&
          l.effectiveLimitMinutes != category.dailyLimitMinutes,
    );
    if (affected) {
      final updated = limits.map((l) {
        if (l.categoryId == category.id) {
          return l.copyWith(effectiveLimitMinutes: category.dailyLimitMinutes);
        }
        return l;
      }).toList();
      await LocalStorage.instance.saveAppLimits(updated);
    }

    _load();
  }

  /// Deletes the category and reassigns its apps to "Uncategorized".
  Future<void> deleteCategory(String categoryId) async {
    // Reassign apps belonging to this category.
    final limits = LocalStorage.instance.getAppLimits();
    final uncat = state.uncategorized ?? AppCategory(
      id: AppConstants.uncategorizedId,
      name: 'Uncategorized',
      color: '#9E9E9E',
      emoji: '📦',
      dailyLimitMinutes: 0,
      isPredefined: false,
    );

    // Ensure the "Uncategorized" fallback exists.
    final uncatExists = state.categories.any((c) => c.id == uncat.id);
    if (!uncatExists) {
      await LocalStorage.instance.upsertAppCategory(uncat);
    }

    final updatedLimits = limits.map((limit) {
      if (limit.categoryId == categoryId) {
        return limit.copyWith(
          categoryId: uncat.id,
          effectiveLimitMinutes: uncat.dailyLimitMinutes,
        );
      }
      return limit;
    }).toList();

    await LocalStorage.instance.saveAppLimits(updatedLimits);
    await LocalStorage.instance.deleteAppCategory(categoryId);
    _load();
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  /// Returns the total used minutes today for all apps in [categoryId].
  int getCategoryUsage(String categoryId) {
    final limits = LocalStorage.instance.getAppLimits();
    return limits
        .where((l) => l.categoryId == categoryId)
        .fold<int>(0, (sum, l) => sum + l.usedMinutesToday);
  }

  /// Returns the [AppCategory] for a given id, or null if not found.
  AppCategory? getById(String categoryId) {
    try {
      return state.categories.firstWhere((c) => c.id == categoryId);
    } catch (_) {
      return null;
    }
  }

  /// Returns the category that contains [packageName], or null if not assigned.
  AppCategory? getCategoryForApp(String packageName) {
    final limits = LocalStorage.instance.getAppLimits();
    for (final l in limits) {
      if (l.packageName == packageName && l.categoryId != null && l.categoryId!.isNotEmpty) {
        return getById(l.categoryId!);
      }
    }
    return null;
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, CategoriesState>(
      (ref) => CategoriesNotifier(),
    );
