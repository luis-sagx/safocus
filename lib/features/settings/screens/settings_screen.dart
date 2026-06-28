import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safocus/core/icons/phosphor_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/localization/app_strings.dart';
import '../../app_limits/providers/app_limits_provider.dart';
// auth_service removed — biometric option UI removed from settings
import '../providers/settings_provider.dart';
import '../../../navigation/app_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  strings.settings,
                  style: AppTypography.displayMedium,
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 24)),

            // ── Appearance ───────────────────────────────────────────
            _section(
              context,
              title: strings.appearance,
              children: [
                _SettingsTile(
                  icon: PhosphorIconsRegular.moon,
                  label: strings.theme,
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<AppThemeMode>(
                      value: settings.themeMode,
                      dropdownColor: context.colors.surfaceVariant,
                      style: AppTypography.bodyMedium.copyWith(
                          color: context.colors.textPrimary),
                      items: [
                        DropdownMenuItem(
                          value: AppThemeMode.dark,
                          child: Text(strings.darkTheme),
                        ),
                        DropdownMenuItem(
                          value: AppThemeMode.light,
                          child: Text(strings.lightTheme),
                        ),
                        DropdownMenuItem(
                          value: AppThemeMode.system,
                          child: Text(strings.systemTheme),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) notifier.setThemeMode(v);
                      },
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: PhosphorIconsRegular.translate,
                  label: strings.language,
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: settings.language,
                      dropdownColor: context.colors.surfaceVariant,
                      style: AppTypography.bodyMedium,
                      items: [
                        DropdownMenuItem(
                          value: 'es',
                          child: Text(strings.spanish),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(strings.english),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) notifier.setLanguage(v);
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 16)),

            // ── Security ─────────────────────────────────────────────
            _section(
              context,
              title: strings.security,
              children: [
                _SettingsTile(
                  icon: PhosphorIconsRegular.lockKey,
                  label: strings.pinProtection,
                  subtitle: strings.pinProtectionSubtitle,
                  trailing: Switch(
                    value: settings.pinEnabled,
                    onChanged: (v) async {
                      if (v) {
                        await _showPinSetupDialog(context, notifier);
                      } else {
                        await notifier.togglePin(false);
                      }
                    },
                    activeColor: AppColors.primary,
                  ),
                ),
                // Biometric authentication option intentionally removed
              ],
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 16)),

            // ── Permisos de bloqueo de apps ───────────────────────────
            _PermissionsSection(),

            const SliverPadding(padding: EdgeInsets.only(top: 16)),

            // ── Data ─────────────────────────────────────────────────
            _section(
              context,
              title: strings.data,
              children: [
                _SettingsTile(
                  icon: PhosphorIconsRegular.trash,
                  label: strings.resetAllData,
                  subtitle: strings.resetAllDataSubtitle,
                  iconColor: AppColors.error,
                  onTap: () => _showResetConfirmDialog(context, ref, notifier),
                ),
              ],
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 16)),

            // ── Legal ─────────────────────────────────────────────────
            _section(
              context,
              title: strings.legalSection,
              children: [
                _SettingsTile(
                  icon: PhosphorIconsRegular.shieldCheck,
                  label: strings.privacyPolicy,
                  onTap: () => context.push(AppRoutes.privacyPolicy),
                ),
                _SettingsTile(
                  icon: PhosphorIconsRegular.fileText,
                  label: strings.termsOfService,
                  onTap: () => context.push(AppRoutes.termsOfService),
                ),
              ],
            ),

            // Version
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Text('${strings.appName} v1.0.0', style: AppTypography.caption),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) => _buildSection(context, title: title, children: children);
}

// Top-level helper so classes outside SettingsScreen can reuse the style.
Widget _buildSection(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) {
  return SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    sliver: SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(title, style: AppTypography.labelMedium),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children:
                  children.asMap().entries.map((e) {
                    final isLast = e.key == children.length - 1;
                    return Column(
                      children: [
                        e.value,
                        if (!isLast)
                          Divider(
                            color: context.colors.divider,
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showPinSetupDialog(
  BuildContext context,
  SettingsNotifier notifier,
) async {
  final strings = AppStrings.of(context);
  final pin = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PinSetupDialog(),
  );

  if (pin != null && context.mounted) {
    await notifier.togglePin(true, pin: pin);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.pinConfiguredSuccessfully)),
      );
    }
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String _errorMsg = '';

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final strings = AppStrings.of(context);
    final p1 = _pinController.text.trim();
    final p2 = _confirmController.text.trim();

    if (p1.length < 4) {
      setState(() => _errorMsg = strings.minimum4Digits);
      return;
    }
    if (p1 != p2) {
      setState(() => _errorMsg = strings.pinsDoNotMatch);
      return;
    }

    Navigator.pop(context, p1);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.surface,
      scrollable: true,
      title: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.lockKey,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(AppStrings.of(context).createPin, style: AppTypography.headlineSmall),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppStrings.of(context).newPinHint,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            decoration: InputDecoration(
              hintText: AppStrings.of(context).confirmPin,
              counterText: '',
              errorText: _errorMsg.isNotEmpty ? _errorMsg : null,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.of(context).cancel),
        ),
        ElevatedButton(onPressed: _submit, child: Text(AppStrings.of(context).save)),
      ],
    );
  }
}

void _showResetConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  SettingsNotifier notifier,
) {
  final strings = AppStrings.of(context);
  showDialog(
    context: context,
    builder:
        (dialogCtx) => AlertDialog(
          title: Text(strings.resetDataTitle),
          content: Text(strings.resetDataBody),
          actions: [
            TextButton(
              onPressed: () {
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              child: Text(strings.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                try {
                  await notifier.resetAllData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.deletedSuccessfully)),
                    );
                  }
                } catch (_) {
                  // Ignore any error to prevent app crash
                }
              },
              child: Text(strings.deleteAll),
            ),
          ],
        ),
  );
}

// ── Settings tile ──────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = AppColors.primary,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label, style: AppTypography.bodyMedium),
      subtitle:
          subtitle != null
              ? Text(subtitle!, style: AppTypography.bodySmall)
              : null,
      trailing:
          trailing ??
          (onTap != null
              ? Icon(
                PhosphorIconsRegular.caretRight,
                color: context.colors.textSecondary,
                size: 16,
              )
              : null),
      onTap: onTap,
    );
  }
}

// ── Permissions section ───────────────────────────────────────────────────────

// ignore: unused_element
class _PermissionsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PermissionsSection> createState() =>
      _PermissionsSectionState();
}

class _PermissionsSectionState extends ConsumerState<_PermissionsSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permissions every time the user comes back from Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appLimitsProvider.notifier).refreshPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final limitsState = ref.watch(appLimitsProvider);
    final notifier = ref.read(appLimitsProvider.notifier);

    return _buildSection(
      context,
      title: AppStrings.of(context).permissionsBlocking,
      children: [
        _PermissionTile(
          icon: PhosphorIconsRegular.chartBar,
          label: AppStrings.of(context).usageStats,
          subtitle: AppStrings.of(context).usageStatsSubtitle,
          granted: limitsState.hasUsagePermission,
          onActivate: () async {
            await notifier.openUsageSettings();
          },
        ),
        _PermissionTile(
          icon: PhosphorIconsRegular.appWindow,
          label: AppStrings.of(context).overlayWindows,
          subtitle: AppStrings.of(context).overlayWindowsSubtitle,
          granted: limitsState.hasOverlayPermission,
          onActivate: () async {
            await notifier.openOverlaySettings();
          },
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.granted,
    required this.onActivate,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool granted;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: icon,
      label: label,
      subtitle: subtitle,
      iconColor: granted ? AppColors.secondary : AppColors.error,
      trailing:
          granted
              ? const Icon(
                PhosphorIconsFill.checkCircle,
                color: AppColors.secondary,
                size: 20,
              )
              : OutlinedButton(
                onPressed: onActivate,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  AppStrings.of(context).activate,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
    );
  }
}
