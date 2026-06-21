import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/focus_score.dart';

class LockInCardWidget extends StatelessWidget {
  const LockInCardWidget({
    super.key,
    required this.lockInScore,
    required this.streakDays,
    required this.focusedMinutesThisWeek,
    required this.cardDate,
    required this.isEnglish,
  });

  final int lockInScore;
  final int streakDays;
  final int focusedMinutesThisWeek;
  final DateTime cardDate;
  final bool isEnglish;

  String get _motivationalPhrase {
    if (lockInScore >= 80) {
      return isEnglish
          ? 'Proof beats promises.'
          : 'La prueba supera las promesas.';
    } else if (lockInScore >= 50) {
      return isEnglish ? 'Built day by day.' : 'Construido día a día.';
    } else {
      return isEnglish
          ? 'Everyone falls. Those who return are locked in.'
          : 'Todos caen. Los que vuelven están locked in.';
    }
  }

  String get _formattedDate {
    return DateFormat('MMM d, yyyy').format(cardDate);
  }

  String get _focusedTime {
    final hours = focusedMinutesThisWeek ~/ 60;
    final minutes = focusedMinutesThisWeek % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = focusScoreColor(lockInScore);

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0F),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            // Subtle gradient overlay at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 160,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0A0A0F).withOpacity(0),
                      accentColor.withOpacity(0.06),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: brand + date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SAFOCUS',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        _formattedDate,
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Lock icon
                  Center(
                    child: Icon(
                      Icons.lock_rounded,
                      size: 40,
                      color: accentColor.withOpacity(0.8),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Score number
                  Center(
                    child: Text(
                      '$lockInScore',
                      style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 88,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: Colors.white,
                      ).copyWith(color: accentColor),
                    ),
                  ),

                  // Score label
                  Center(
                    child: Text(
                      isEnglish ? 'Lock-In Score' : 'Lock-In Score',
                      style: AppTypography.labelMedium.copyWith(
                        color: Colors.white.withOpacity(0.55),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  Divider(color: Colors.white.withOpacity(0.1), thickness: 1),

                  const SizedBox(height: 20),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatChip(
                        icon: '🔥',
                        value: '$streakDays',
                        label: isEnglish
                            ? (streakDays == 1 ? 'day locked in' : 'days locked in')
                            : (streakDays == 1 ? 'día locked in' : 'días locked in'),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      _StatChip(
                        icon: '⏱',
                        value: _focusedTime,
                        label: isEnglish ? 'focused this week' : 'enfocado esta semana',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Motivational phrase
                  Center(
                    child: Text(
                      _motivationalPhrase,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Watermark
                  Center(
                    child: Text(
                      '@safocus',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withOpacity(0.25),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.45),
          ),
        ),
      ],
    );
  }
}
