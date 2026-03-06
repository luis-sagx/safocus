import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/app_limit.dart';
import '../providers/app_limits_provider.dart';
import '../../auth/screens/auth_screen.dart';

class AppLimitsScreen extends ConsumerWidget {
  const AppLimitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appLimitsProvider);
    final notifier = ref.read(appLimitsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Límites de Apps', style: AppTypography.displayMedium),
                    Text(
                      'Controla cuánto tiempo usas cada aplicación',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 24)),

            // ── List ──────────────────────────────────────────────────
            state.limits.isEmpty
                ? SliverFillRemaining(
                  child: _EmptyState(
                    onAdd: () async {
                      await requireAuth(
                        context,
                        onAuthed: () => _showAddDialog(context, notifier),
                      );
                    },
                  ),
                )
                : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList.separated(
                    itemCount: state.limits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder:
                        (_, i) => _AppLimitCard(
                          limit: state.limits[i],
                          onToggle: () async {
                            await requireAuth(
                              context,
                              onAuthed:
                                  () => notifier.toggleLimit(state.limits[i]),
                            );
                          },
                          onDelete: () async {
                            await requireAuth(
                              context,
                              onAuthed:
                                  () =>
                                      notifier.deleteLimit(state.limits[i].id),
                            );
                          },
                          onEmergency: () async {
                            bool result = false;
                            await requireAuth(
                              context,
                              onAuthed: () async {
                                result = await notifier
                                    .requestEmergencyExtension(
                                      state.limits[i].id,
                                    );
                              },
                            );
                            return result;
                          },
                        ),
                  ),
                ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await requireAuth(
            context,
            onAuthed: () => _showAddDialog(context, notifier),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(
          PhosphorIconsRegular.plus,
          color: AppColors.textPrimary,
        ),
        label: Text(
          'Agregar app',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    AppLimitsNotifier notifier,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _AddLimitSheet(
            onAdd:
                ({
                  required packageName,
                  required appName,
                  required limitMins,
                }) => notifier.addLimit(
                  packageName: packageName,
                  appName: appName,
                  dailyLimitMinutes: limitMins,
                ),
          ),
    );
  }
}

// ── App Limit Card ─────────────────────────────────────────────────────────

class _AppLimitCard extends StatelessWidget {
  const _AppLimitCard({
    required this.limit,
    required this.onToggle,
    required this.onDelete,
    required this.onEmergency,
  });
  final AppLimit limit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Future<bool> Function() onEmergency;

  @override
  Widget build(BuildContext context) {
    final exceeded = limit.isExceeded;
    final progress = limit.progressRatio;
    final Color trackColor =
        exceeded
            ? AppColors.error
            : progress > 0.8
            ? AppColors.warning
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border:
            exceeded
                ? Border.all(color: AppColors.error.withOpacity(0.4))
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    limit.appName.substring(0, 1).toUpperCase(),
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(limit.appName, style: AppTypography.labelLarge),
                    Text(
                      limit.packageName,
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: limit.isActive,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.primary,
              ),
              PopupMenuButton<String>(
                color: AppColors.surfaceVariant,
                onSelected: (v) async {
                  if (v == 'delete') onDelete();
                },
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.trash,
                              color: AppColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Eliminar',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatMinutes(limit.usedMinutesToday) + ' usado',
                style: AppTypography.labelMedium,
              ),
              Text(
                'Límite: ' + formatMinutes(limit.dailyLimitMinutes),
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(trackColor),
            ),
          ),

          // Emergency extension
          if (exceeded && !limit.emergencyExtUsedToday) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                ),
                onPressed: () async {
                  final ok = await onEmergency();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ya utilizaste la extensión de emergencia hoy.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(
                  PhosphorIconsRegular.clockCounterClockwise,
                  size: 16,
                ),
                label: Text(
                  'Extensión de emergencia +${AppConstants.emergencyExtensionMinutes}min',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsFill.clockCountdown,
                color: AppColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin límites configurados',
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega aplicaciones y establece el tiempo máximo diario permitido.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(PhosphorIconsRegular.plus, size: 18),
              label: const Text('Agregar aplicación'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add limit sheet ────────────────────────────────────────────────────────

typedef _OnAdd =
    Future<void> Function({
      required String packageName,
      required String appName,
      required int limitMins,
    });

// Model for an installed app entry
class _InstalledApp {
  final String name;
  final String packageName;
  const _InstalledApp({required this.name, required this.packageName});
}

class _AddLimitSheet extends StatefulWidget {
  const _AddLimitSheet({required this.onAdd});
  final _OnAdd onAdd;

  @override
  State<_AddLimitSheet> createState() => _AddLimitSheetState();
}

class _AddLimitSheetState extends State<_AddLimitSheet> {
  static const _appsChannel = MethodChannel('com.example.safocus/apps');

  // Step 1: app picker
  List<_InstalledApp>? _allApps;
  List<_InstalledApp> _filtered = [];
  bool _loadingApps = true;
  String _errorMsg = '';
  final _searchCtrl = TextEditingController();

  // Step 2: time picker
  _InstalledApp? _selectedApp;
  int _selectedMinutes = 60;
  bool _saving = false;

  static final _presets = [
    (label: '15 min', value: 15),
    (label: '30 min', value: 30),
    (label: '1 hora', value: 60),
    (label: '2 horas', value: 120),
  ];

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    try {
      final raw = await _appsChannel.invokeListMethod<Map>('getInstalledApps');
      final apps =
          (raw ?? [])
              .map(
                (m) => _InstalledApp(
                  name: m['name'] as String,
                  packageName: m['package'] as String,
                ),
              )
              .toList();
      if (mounted) {
        setState(() {
          _allApps = apps;
          _filtered = apps;
          _loadingApps = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'No se pudieron cargar las apps: $e';
          _loadingApps = false;
        });
      }
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered =
          (_allApps ?? [])
              .where(
                (a) =>
                    a.name.toLowerCase().contains(q) ||
                    a.packageName.toLowerCase().contains(q),
              )
              .toList();
    });
  }

  void _selectApp(_InstalledApp app) {
    setState(() => _selectedApp = app);
  }

  void _back() {
    setState(() => _selectedApp = null);
  }

  Future<void> _save() async {
    final app = _selectedApp;
    if (app == null) return;
    setState(() => _saving = true);
    await widget.onAdd(
      packageName: app.packageName,
      appName: app.name,
      limitMins: _selectedMinutes,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _selectedApp == null ? _buildPickerStep() : _buildTimeStep(),
      ),
    );
  }

  // ── Step 1: Searchable app list ──────────────────────────────────────────

  Widget _buildPickerStep() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seleccionar app',
                        style: AppTypography.headlineMedium,
                      ),
                      Text(
                        'Elige la app a la que quieres poner límite',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    PhosphorIconsRegular.x,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar app...',
                prefixIcon: const Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            PhosphorIconsRegular.x,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => _searchCtrl.clear(),
                        )
                        : null,
              ),
            ),
          ),
          // App list
          Expanded(
            child:
                _loadingApps
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                    : _errorMsg.isNotEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMsg,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : _filtered.isEmpty
                    ? Center(
                      child: Text(
                        'Sin resultados',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final app = _filtered[i];
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                app.name[0].toUpperCase(),
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            app.name,
                            style: AppTypography.bodyMedium,
                          ),
                          subtitle: Text(
                            app.packageName,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () => _selectApp(app),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Time limit picker ────────────────────────────────────────────

  Widget _buildTimeStep() {
    final app = _selectedApp!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back + title
          Row(
            children: [
              IconButton(
                onPressed: _back,
                icon: const Icon(
                  PhosphorIconsRegular.arrowLeft,
                  color: AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text('Límite de tiempo', style: AppTypography.headlineMedium),
            ],
          ),
          const SizedBox(height: 16),
          // Selected app chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      app.name[0].toUpperCase(),
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.name, style: AppTypography.bodyMedium),
                      Text(
                        app.packageName,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Tiempo máximo diario', style: AppTypography.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _presets.map((p) {
                  final selected = p.value == _selectedMinutes;
                  return ChoiceChip(
                    label: Text(p.label),
                    selected: selected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                    onSelected:
                        (_) => setState(() => _selectedMinutes = p.value),
                    labelStyle: AppTypography.labelMedium.copyWith(
                      color:
                          selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child:
                  _saving
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Guardar límite'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
