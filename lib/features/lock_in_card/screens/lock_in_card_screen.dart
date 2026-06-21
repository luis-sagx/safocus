import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../statistics/providers/statistics_provider.dart';
import '../widgets/lock_in_card_widget.dart';

class LockInCardScreen extends ConsumerStatefulWidget {
  const LockInCardScreen({super.key});

  @override
  ConsumerState<LockInCardScreen> createState() => _LockInCardScreenState();
}

class _LockInCardScreenState extends ConsumerState<LockInCardScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _shareCard() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
      );
      if (imageBytes == null) return;

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/lock_in_card.png';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'image/png')],
        text: _shareText,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String get _shareText {
    final strings = AppStrings.forLanguage(
      Localizations.localeOf(context).languageCode,
    );
    return strings.isEnglish
        ? 'My Lock-In Score this week 🔒 #safocus #lockedin'
        : 'Mi Lock-In Score esta semana 🔒 #safocus #lockedin';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statisticsProvider);
    final strings = AppStrings.of(context);

    final int focusedMinutes = state.weekStats
        .map((s) => s.usageMinutes)
        .fold(0, (sum, m) => sum + m);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          strings.isEnglish ? 'Lock-In Card' : 'Lock-In Card',
          style: AppTypography.headlineSmall,
        ),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Screenshot(
                    controller: _screenshotController,
                    child: LockInCardWidget(
                      lockInScore: state.todayLockInScore,
                      streakDays: state.streakDays,
                      focusedMinutesThisWeek: focusedMinutes,
                      cardDate: DateTime.now(),
                      isEnglish: strings.isEnglish,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSharing ? null : _shareCard,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(PhosphorIconsFill.shareNetwork),
                  label: Text(
                    _isSharing
                        ? (strings.isEnglish ? 'Preparing...' : 'Preparando...')
                        : (strings.isEnglish ? 'Share Card' : 'Compartir Card'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: AppTypography.labelLarge,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
