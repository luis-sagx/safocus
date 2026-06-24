import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';

class LegalSection extends StatelessWidget {
  const LegalSection({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headlineSmall),
          const SizedBox(height: 8),
          SelectableText(
            body,
            style: AppTypography.bodyMedium.copyWith(
              color: context.colors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
