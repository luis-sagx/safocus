import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Calculates a daily focus score (0–100) based on:
///  - vpnActive weight 30
///  - limitsRespected weight 50
///  - notificationsInteracted weight 20
int calculateFocusScore({
  required bool vpnActive,
  required double limitsRespectedRatio, // 0.0 – 1.0
  required bool notificationsInteracted,
}) {
  int score = 0;
  if (vpnActive) score += 30;
  score += (limitsRespectedRatio * 50).round();
  if (notificationsInteracted) score += 20;
  return score.clamp(0, 100);
}

/// Returns the color representing a focus score value.
Color focusScoreColor(int score) {
  if (score >= 80) return AppColors.secondary;
  if (score >= 50) return AppColors.warning;
  return AppColors.error;
}
