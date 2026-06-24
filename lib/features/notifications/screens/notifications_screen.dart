import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/motivational_phrase.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.motivation, style: AppTypography.displayMedium),
                    Text(
                      strings.phrasesReminder,
                      style: AppTypography.bodyMedium.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 20)),

            // Settings card
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: _SettingsCard(
                  enabled: state.enabled,
                  intervalHours: state.intervalHours,
                  onEnabledToggle: notifier.setEnabled,
                  onIntervalChange: notifier.setInterval,
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 24)),

            // Phrases header
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.phrasesCount(state.phrases.length),
                      style: AppTypography.headlineSmall,
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddPhraseDialog(context, notifier),
                      icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                      label: Text(strings.addPhrase),
                    ),
                  ],
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 8)),

            // Phrases list
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.separated(
                itemCount: state.phrases.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final phrase = state.phrases[i];
                  return _PhraseTile(
                    phrase: phrase,
                    onToggle: () => notifier.togglePhrase(phrase),
                    onDelete: phrase.isDefault
                        ? null
                        : () => notifier.deletePhrase(phrase.id),
                  );
                },
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  void _showAddPhraseDialog(
    BuildContext context,
    NotificationsNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddPhraseSheet(
        onAdd: (text, lang) => notifier.addPhrase(text, lang),
      ),
    );
  }
}

// ── Settings card ──────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.enabled,
    required this.intervalHours,
    required this.onEnabledToggle,
    required this.onIntervalChange,
  });
  final bool enabled;
  final int intervalHours;
  final Future<void> Function(bool) onEnabledToggle;
  final Future<void> Function(int) onIntervalChange;

  static const _intervals = [1, 2, 3, 4, 6, 8];

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.activeReminders,
                    style: AppTypography.labelLarge,
                  ),
                  Text(
                    strings.receiveMotivationalPhrases,
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
              Switch(
                value: enabled,
                onChanged: onEnabledToggle,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 16),
            Divider(color: context.colors.divider),
            const SizedBox(height: 16),
            Text(strings.frequency, style: AppTypography.headlineSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _intervals.map((h) {
                final selected = h == intervalHours;
                return ChoiceChip(
                  label: Text(strings.everyHours(h)),
                  selected: selected,
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  onSelected: (_) => onIntervalChange(h),
                  labelStyle: AppTypography.labelMedium.copyWith(
                    color: selected ? AppColors.primary : context.colors.textPrimary,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Phrase tile ────────────────────────────────────────────────────────────

class _PhraseTile extends StatelessWidget {
  const _PhraseTile({
    required this.phrase,
    required this.onToggle,
    this.onDelete,
  });
  final MotivationalPhrase phrase;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: phrase.isActive ? null : Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              phrase.lang.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              phrase.text,
              style: AppTypography.bodyMedium.copyWith(
                color: phrase.isActive
                    ? context.colors.textPrimary
                    : context.colors.textDisabled,
              ),
            ),
          ),
          Column(
            children: [
              Switch(
                value: phrase.isActive,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.primary,
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(
                    PhosphorIconsRegular.trash,
                    size: 16,
                    color: AppColors.error,
                  ),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add phrase sheet ───────────────────────────────────────────────────────

class _AddPhraseSheet extends StatefulWidget {
  const _AddPhraseSheet({required this.onAdd});
  final Future<void> Function(String text, String lang) onAdd;

  @override
  State<_AddPhraseSheet> createState() => _AddPhraseSheetState();
}

class _AddPhraseSheetState extends State<_AddPhraseSheet> {
  final _ctrl = TextEditingController();
  String _lang = 'es';
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.newPhrase, style: AppTypography.headlineMedium),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: strings.writeInspiringPhrase,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(strings.languageLabel, style: AppTypography.labelMedium),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(strings.spanish),
                  selected: _lang == 'es',
                  onSelected: (_) => setState(() => _lang = 'es'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(strings.english),
                  selected: _lang == 'en',
                  onSelected: (_) => setState(() => _lang = 'en'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: Text(strings.savePhrase),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    await widget.onAdd(text, _lang);
    if (mounted) Navigator.pop(context);
  }
}
