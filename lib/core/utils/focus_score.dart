import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Calculates a daily Lock-In Score (0–100) based on:
///  - vpnActive: 25 pts
///  - limitsRespectedRatio: up to 40 pts
///  - streakDays: up to 20 pts (2 pts/day, capped at 10 days)
///  - duoCompletedToday: 15 pts
int calculateLockInScore({
  required bool vpnActive,
  required double limitsRespectedRatio, // 0.0 – 1.0
  int streakDays = 0,
  bool duoCompletedToday = false,
}) {
  int score = 0;
  if (vpnActive) score += 25;
  score += (limitsRespectedRatio * 40).round();
  score += (streakDays.clamp(0, 10) * 2);
  if (duoCompletedToday) score += 15;
  return score.clamp(0, 100);
}

/// Backward-compatible alias — callers that haven't migrated yet still work.
int calculateFocusScore({
  required bool vpnActive,
  required double limitsRespectedRatio,
  bool notificationsInteracted = false,
}) => calculateLockInScore(
  vpnActive: vpnActive,
  limitsRespectedRatio: limitsRespectedRatio,
);

/// Returns the color representing a Lock-In Score value.
Color focusScoreColor(int score) {
  if (score >= 80) return AppColors.secondary;
  if (score >= 50) return AppColors.warning;
  return AppColors.error;
}
