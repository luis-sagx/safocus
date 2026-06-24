import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme-aware semantic palette.
///
/// Screens read structural colors through [BuildContext.colors] instead of the
/// static [AppColors] tokens, so the same widget renders correctly in both the
/// dark and light themes. Brand colors (primary, secondary, error, warning,
/// success) are identical across themes and remain available on [AppColors].
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.divider,
    required this.border,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color divider;
  final Color border;

  static const AppPalette dark = AppPalette(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceVariant: AppColors.surfaceVariant,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textDisabled: AppColors.textDisabled,
    divider: AppColors.divider,
    border: AppColors.border,
  );

  static const AppPalette light = AppPalette(
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    surfaceVariant: AppColors.surfaceVariantLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    textDisabled: AppColors.textDisabledLight,
    divider: AppColors.dividerLight,
    border: AppColors.borderLight,
  );

  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;
}

extension AppPaletteX on BuildContext {
  /// The theme-aware semantic palette for the current brightness.
  AppPalette get colors =>
      AppPalette.of(Theme.of(this).brightness);
}
