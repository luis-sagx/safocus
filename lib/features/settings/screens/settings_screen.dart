import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/settings_provider.dart';
import '../../app_limits/providers/app_limits_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/screens/auth_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Configuración',
                  style: AppTypography.displayMedium,
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 24)),

            // ── Appearance ───────────────────────────────────────────
            _section(
              context,
              title: 'Apariencia',
              children: [
                _SettingsTile(
                  icon: PhosphorIconsRegular.moon,
                  label: 'Tema',
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<AppThemeMode>(
                      value: settings.themeMode,
                      dropdownColor: AppColors.surfaceVariant,
                      style: AppTypography.bodyMedium,
                      items: const [
                        DropdownMenuItem(
                          value: AppThemeMode.dark,
                          child: Text('Oscuro'),
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
                  label: 'Idioma',
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: settings.language,
                      dropdownColor: AppColors.surfaceVariant,
                      style: AppTypography.bodyMedium,
                      items: const [
                        DropdownMenuItem(value: 'es', child: Text('Español')),
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
              title: 'Seguridad',
              children: [
                _SettingsTile(
                  icon: PhosphorIconsRegular.lockKey,
                  label: 'PIN de protección',
                  subtitle: 'Requiere PIN para desactivar bloqueos',
                  trailing: Switch(
                    value: settings.pinEnabled,
                    onChanged: (v) async {
                      if (v) {
                        await _showPinSetupDialog(context, notifier);
                      } else {
                        // Require current PIN to disable
                        await requireAuth(
                          context,
                          onAuthed: () => notifier.togglePin(false),
                        );
                      }
                    },
                    activeColor: AppColors.primary,
                  ),
                ),
                _SettingsTile(
                  icon: PhosphorIconsRegular.fingerprint,
                  label: 'Autenticación biométrica',
                  subtitle: 'Huella o Face ID como alternativa al PIN',
                  trailing: Switch(
                    value: settings.biometricEnabled,
                    onChanged: (v) async {
                      if (v) {
                        final auth = AuthService.instance;
                        final available = await auth.isBiometricAvailable;
                        if (!available) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No hay biometría disponible en este dispositivo.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        // Verify biometric works before enabling
                        final ok = await auth.authenticateWithBiometrics(
                          reason: 'Confirma tu biometría para activarla',
                        );
                        if (ok) await notifier.toggleBiometric(true);
                      } else {
                        await notifier.toggleBiometric(false);
                      }
                    },
                    activeColor: AppColors.primary,
                  ),
                ),
              ],
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 16)),

            // ── Quiet hours ───────────────────────────────────────────
            _section(
              context,
              title: 'Horas de silencio',
              children: [
                _SettingsTile(
                  icon: PhosphorIconsRegular.bellSlash,
                  label: 'Sin notificaciones',
                  subtitle:
                      '${settings.quietStartHour}:00 — ${settings.quietEndHour}:00',
                  onTap:
                      () => _showQuietHoursDialog(
                        context,
                        notifier,
                        settings.quietStartHour,
                        settings.quietEndHour,
                      ),
                ),
              ],
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 16)),

            // ── Permisos de bloqueo de apps ───────────────────────────
            _PermissionsSection(),

            const SliverPadding(padding: EdgeInsets.only(top: 16)),

            // ── Data ─────────────────────────────────────────────────
            _section(
              context,
              title: 'Datos',
              children: [
                _SettingsTile(
                  icon: PhosphorIconsRegular.trash,
                  label: 'Restablecer todos los datos',
                  subtitle: 'Borra configuración, límites y estadísticas',
                  iconColor: AppColors.error,
                  onTap: () => _showResetConfirmDialog(context, ref, notifier),
                ),
              ],
            ),

            // Version
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Text('SaFocus v1.0.0', style: AppTypography.caption),
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
              color: AppColors.surface,
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
                          const Divider(
                            color: AppColors.divider,
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
  final ctrl1 = TextEditingController();
  final ctrl2 = TextEditingController();
  String errorMsg = '';

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (_, setState) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.lockKey,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text('Crear PIN', style: AppTypography.headlineSmall),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: ctrl1,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Nuevo PIN (4–6 dígitos)',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrl2,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Confirmar PIN',
                        counterText: '',
                        errorText: errorMsg.isNotEmpty ? errorMsg : null,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final p1 = ctrl1.text.trim();
                      final p2 = ctrl2.text.trim();
                      if (p1.length < 4) {
                        setState(() => errorMsg = 'Mínimo 4 dígitos');
                        return;
                      }
                      if (p1 != p2) {
                        setState(() => errorMsg = 'Los PINs no coinciden');
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
        ),
  );

  if (confirmed == true && context.mounted) {
    final pin = ctrl1.text.trim();
    await notifier.togglePin(true, pin: pin);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN configurado correctamente.')),
      );
    }
  }
  ctrl1.dispose();
  ctrl2.dispose();
}

void _showQuietHoursDialog(
  BuildContext context,
  SettingsNotifier notifier,
  int start,
  int end,
) {
  int _start = start;
  int _end = end;
  showDialog(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (_, setState) => AlertDialog(
                title: const Text('Horas de silencio'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Inicio', style: AppTypography.bodyMedium),
                        DropdownButton<int>(
                          value: _start,
                          dropdownColor: AppColors.surfaceVariant,
                          items: List.generate(
                            24,
                            (h) => DropdownMenuItem(
                              value: h,
                              child: Text('${h.toString().padLeft(2, '0')}:00'),
                            ),
                          ),
                          onChanged: (v) {
                            if (v != null) setState(() => _start = v);
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fin', style: AppTypography.bodyMedium),
                        DropdownButton<int>(
                          value: _end,
                          dropdownColor: AppColors.surfaceVariant,
                          items: List.generate(
                            24,
                            (h) => DropdownMenuItem(
                              value: h,
                              child: Text('${h.toString().padLeft(2, '0')}:00'),
                            ),
                          ),
                          onChanged: (v) {
                            if (v != null) setState(() => _end = v);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      notifier.setQuietHours(_start, _end);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
        ),
  );
}

void _showResetConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  SettingsNotifier notifier,
) {
  showDialog(
    context: context,
    builder:
        (dialogCtx) => AlertDialog(
          title: const Text('Restablecer datos'),
          content: const Text(
            'Esta acción eliminará todos los límites, bloqueos, estadísticas y configuración. No se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                try {
                  await requireAuth(
                    context,
                    onAuthed: () async {
                      await notifier.resetAllData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Datos eliminados correctamente.'),
                          ),
                        );
                      }
                    },
                  );
                } catch (_) {
                  // Ignore any error to prevent app crash
                }
              },
              child: const Text('Eliminar todo'),
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
              ? const Icon(
                PhosphorIconsRegular.caretRight,
                color: AppColors.textSecondary,
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
      title: 'Permisos de bloqueo',
      children: [
        _PermissionTile(
          icon: PhosphorIconsRegular.chartBar,
          label: 'Estadísticas de uso',
          subtitle: 'Necesario para detectar el tiempo en cada app',
          granted: limitsState.hasUsagePermission,
          onActivate: () async {
            await notifier.openUsageSettings();
          },
        ),
        _PermissionTile(
          icon: PhosphorIconsRegular.appWindow,
          label: 'Superponer ventanas',
          subtitle: 'Necesario para mostrar la pantalla de bloqueo',
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
                  'Activar',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
    );
  }
}
