import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safocus/core/icons/phosphor_icons.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/duo_pair.dart';
import '../providers/duo_provider.dart';

class DuoScreen extends ConsumerStatefulWidget {
  const DuoScreen({super.key});

  @override
  ConsumerState<DuoScreen> createState() => _DuoScreenState();
}

class _DuoScreenState extends ConsumerState<DuoScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _joiningLoading = false;
  bool _creatingLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    final strings = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.copiedToClipboard),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.colors.surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleCreate() async {
    setState(() => _creatingLoading = true);
    await ref.read(duoProvider.notifier).createDuo();
    if (mounted) setState(() => _creatingLoading = false);
  }

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _joiningLoading = true);
    await ref.read(duoProvider.notifier).setPartner(
          partnerCode: code,
          partnerName:
              _nameController.text.trim().isNotEmpty
                  ? _nameController.text.trim()
                  : null,
        );
    if (mounted) setState(() => _joiningLoading = false);
  }

  Future<void> _handleCheckIn() async {
    await ref.read(duoProvider.notifier).checkInToday();
  }

  Future<void> _handleLeave(BuildContext context) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(strings.leaveDuo, style: AppTypography.headlineSmall),
        content: Text(
          strings.leaveDuoConfirm,
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              strings.cancel,
              style: AppTypography.labelMedium.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              strings.leaveDuo,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(duoProvider.notifier).leaveDuo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final duo = ref.watch(duoProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
        title: Text(strings.focusDuo, style: AppTypography.headlineMedium),
      ),
      body: SafeArea(
        child: duo == null
            ? _buildSetup(context, strings)
            : _buildActive(context, strings, duo),
      ),
    );
  }

  // ── Setup state (no duo yet) ────────────────────────────────────────────

  Widget _buildSetup(BuildContext context, AppStrings strings) {
    final duo = ref.watch(duoProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Header
        Text(strings.noDuoYet, style: AppTypography.headlineLarge),
        const SizedBox(height: 4),
        Text(
          strings.focusDuoSubtitle,
          style: AppTypography.bodyMedium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 32),

        // Card 1: Create / show my code
        _SectionCard(
          child: duo == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.myInviteCode,
                      style: AppTypography.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.startDuo,
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    _PrimaryButton(
                      label: strings.startDuo,
                      loading: _creatingLoading,
                      onTap: _handleCreate,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.myInviteCode,
                      style: AppTypography.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    _CodeBox(code: duo.myCode, onCopy: () => _copyCode(duo.myCode)),
                  ],
                ),
        ),

        const SizedBox(height: 16),

        // Card 2: Join with partner code
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.enterPartnerCode,
                style: AppTypography.headlineSmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: strings.codePlaceholder,
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: context.colors.textDisabled,
                  ),
                  filled: true,
                  fillColor: context.colors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: strings.partnerName,
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: context.colors.textDisabled,
                  ),
                  filled: true,
                  fillColor: context.colors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PrimaryButton(
                label: strings.joinDuo,
                loading: _joiningLoading,
                onTap: _handleJoin,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Active state (duo exists) ───────────────────────────────────────────

  Widget _buildActive(BuildContext context, AppStrings strings, DuoPair duo) {
    final partnerDisplay = duo.partnerName ?? duo.partnerCode ?? '';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Streak hero
        _SectionCard(
          child: Column(
            children: [
              Text(
                '🔥 ${duo.sharedStreakDays}',
                style: AppTypography.displayLarge.copyWith(
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.duoStreakLabel(duo.sharedStreakDays),
                style: AppTypography.bodyMedium.copyWith(
                  color: context.colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                strings.duoActive,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Partner info
        if (partnerDisplay.isNotEmpty)
          _SectionCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    PhosphorIconsFill.users,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duo with',
                      style: AppTypography.labelMedium,
                    ),
                    Text(
                      partnerDisplay,
                      style: AppTypography.labelLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),

        if (partnerDisplay.isNotEmpty) const SizedBox(height: 16),

        // Today's check-in
        _SectionCard(
          child: duo.myCheckedInToday
              ? Column(
                  children: [
                    const Icon(
                      PhosphorIconsFill.checkCircle,
                      color: AppColors.secondary,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.lockedInToday,
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See you tomorrow 💪',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.notYetToday,
                      style: AppTypography.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    _PrimaryButton(
                      label: strings.lockedInToday,
                      loading: false,
                      onTap: _handleCheckIn,
                      color: AppColors.secondary,
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 16),

        // My invite code (small, copyable)
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.myInviteCode, style: AppTypography.labelMedium),
              const SizedBox(height: 8),
              _CodeBox(code: duo.myCode, onCopy: () => _copyCode(duo.myCode)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Leave duo (destructive)
        GestureDetector(
          onTap: () => _handleLeave(context),
          child: Center(
            child: Text(
              strings.leaveDuo,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Private sub-widgets ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code, required this.onCopy});
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code,
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.primary,
                letterSpacing: 2,
              ),
            ),
          ),
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                PhosphorIconsRegular.copy,
                color: AppColors.primary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
    this.color = AppColors.primary,
  });
  final String label;
  final bool loading;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
