import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/constants/blocked_sites.dart';
import '../../../data/models/blocked_site.dart';
import '../providers/blocking_provider.dart';
import '../../auth/screens/auth_screen.dart';

class BlockingScreen extends ConsumerStatefulWidget {
  const BlockingScreen({super.key});

  @override
  ConsumerState<BlockingScreen> createState() => _BlockingScreenState();
}

class _BlockingScreenState extends ConsumerState<BlockingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(blockingProvider);
    final notifier = ref.read(blockingProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder:
              (_, __) => [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bloqueo Web', style: AppTypography.displayMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Activa el escudo VPN para bloquear sitios distractores',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // VPN toggle card
                        _VpnCard(
                          isActive: state.vpnActive,
                          activeSites:
                              state.sites.where((s) => s.isActive).length,
                          onToggle: () async {
                            await requireAuth(
                              context,
                              onAuthed: () async {
                                final ok = await notifier.toggleVpn();
                                if (!ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No se pudo activar el VPN. Verifica los permisos.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        TabBar(
                          controller: _tabs,
                          indicatorColor: AppColors.primary,
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textSecondary,
                          labelStyle: AppTypography.labelLarge,
                          unselectedLabelStyle: AppTypography.labelMedium,
                          dividerColor: AppColors.divider,
                          tabs: const [
                            Tab(text: 'Mis sitios'),
                            Tab(text: 'Predefinidos'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
          body: TabBarView(
            controller: _tabs,
            children: [
              // ── Custom sites ─────────────────────────────────────────
              _CustomSitesList(
                sites: state.sites.where((s) => !s.isDefault).toList(),
                onToggle: notifier.toggleSite,
                onDelete: (id) async {
                  await requireAuth(
                    context,
                    onAuthed: () => notifier.deleteSite(id),
                  );
                },
                onAdd: _showAddDialog,
              ),
              // ── Default sites by category ────────────────────────────
              _DefaultSitesList(
                sites: state.sites.where((s) => s.isDefault).toList(),
                onToggle: notifier.toggleSite,
                onCategoryToggle: notifier.activateCategory,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(
          PhosphorIconsRegular.plus,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _AddSiteSheet(
            onAdd:
                (domain) => ref.read(blockingProvider.notifier).addSite(domain),
          ),
    );
  }
}

// ── VPN Toggle Card ───────────────────────────────────────────────────────

class _VpnCard extends StatelessWidget {
  const _VpnCard({
    required this.isActive,
    required this.activeSites,
    required this.onToggle,
  });
  final bool isActive;
  final int activeSites;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.secondary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              isActive
                  ? AppColors.secondary.withOpacity(0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isActive
                    ? AppColors.secondary.withOpacity(0.4)
                    : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive
                    ? PhosphorIconsFill.shieldCheck
                    : PhosphorIconsFill.shieldWarning,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? 'Escudo Activo' : 'Escudo Inactivo',
                    style: AppTypography.headlineSmall.copyWith(color: color),
                  ),
                  Text(
                    isActive
                        ? '$activeSites sitios bloqueados'
                        : 'Toca para activar el bloqueo VPN',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: isActive,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom sites list ──────────────────────────────────────────────────────

class _CustomSitesList extends StatelessWidget {
  const _CustomSitesList({
    required this.sites,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
  });
  final List<BlockedSite> sites;
  final Future<void> Function(BlockedSite) onToggle;
  final Future<void> Function(String) onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (sites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsRegular.plusCircle,
                color: AppColors.textSecondary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Sin sitios personalizados',
                style: AppTypography.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Agrega URLs que quieres bloquear',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                label: const Text('Agregar sitio'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: sites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder:
          (_, i) => _SiteTile(
            site: sites[i],
            onToggle: () => onToggle(sites[i]),
            onDelete: () => onDelete(sites[i].id),
          ),
    );
  }
}

// ── Default sites list ─────────────────────────────────────────────────────

class _DefaultSitesList extends StatelessWidget {
  const _DefaultSitesList({
    required this.sites,
    required this.onToggle,
    required this.onCategoryToggle,
  });
  final List<BlockedSite> sites;
  final Future<void> Function(BlockedSite) onToggle;
  final Future<void> Function(String, bool) onCategoryToggle;

  @override
  Widget build(BuildContext context) {
    final categories = BlockedSites.defaultByCategory.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final category = categories[i];
        final catSites = sites.where((s) => s.category == category).toList();
        final allActive = catSites.every((s) => s.isActive);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(category, style: AppTypography.headlineSmall),
                Switch(
                  value: allActive,
                  onChanged: (v) => onCategoryToggle(category, v),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...catSites.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _SiteTile(
                  site: s,
                  onToggle: () => onToggle(s),
                  onDelete: null, // default sites cannot be deleted
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Individual tile ───────────────────────────────────────────────────────

class _SiteTile extends StatelessWidget {
  const _SiteTile({required this.site, required this.onToggle, this.onDelete});
  final BlockedSite site;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.globeSimple,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(site.domain, style: AppTypography.bodyMedium)),
          if (onDelete != null)
            IconButton(
              icon: const Icon(
                PhosphorIconsRegular.trash,
                size: 18,
                color: AppColors.error,
              ),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          Switch(
            value: site.isActive,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ── Add site bottom sheet ─────────────────────────────────────────────────

class _AddSiteSheet extends StatefulWidget {
  const _AddSiteSheet({required this.onAdd});
  final Future<void> Function(String) onAdd;

  @override
  State<_AddSiteSheet> createState() => _AddSiteSheetState();
}

class _AddSiteSheetState extends State<_AddSiteSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agregar sitio', style: AppTypography.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Introduce el dominio sin "https://" (ej. facebook.com)',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'dominio.com',
                prefixIcon: Icon(
                  PhosphorIconsRegular.globeSimple,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child:
                    _loading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Agregar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final domain = _ctrl.text.trim();
    if (domain.isEmpty) return;
    setState(() => _loading = true);
    await widget.onAdd(domain);
    if (mounted) Navigator.pop(context);
  }
}
