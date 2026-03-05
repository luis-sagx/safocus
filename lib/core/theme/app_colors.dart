import 'package:flutter/material.dart';

/// Design token palette for SaFocus.
/// Dark‑first; light variants mirrored where needed.
abstract class AppColors {
  // ── Backgrounds ─────────────────────────────────────────────────────────
  static const Color background = Color(0xFF0F1117);
  static const Color surface = Color(0xFF1A1D2E);
  static const Color surfaceVariant = Color(0xFF222538);

  // ── Accents ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6C63FF); // indigo vibrante
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color secondary = Color(0xFF00D4AA); // verde menta
  static const Color secondaryLight = Color(0xFF4DFFDB);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFFB347);
  static const Color success = Color(0xFF00D4AA);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8A8FA8);
  static const Color textDisabled = Color(0xFF4A4F68);

  // ── Divider / Border ─────────────────────────────────────────────────────
  static const Color divider = Color(0xFF2A2D42);
  static const Color border = Color(0xFF2E3150);

  // ── Light theme ──────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF5F6FF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F1117);
  static const Color textSecondaryLight = Color(0xFF4A4F68);
}
