import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/local_storage.dart';
import '../../../data/models/blocked_site.dart';
import '../../../core/constants/app_constants.dart';

// ── State ─────────────────────────────────────────────────────────────────

class BlockingState {
  final List<BlockedSite> sites;
  final bool vpnActive;
  final bool isLoading;

  const BlockingState({
    this.sites = const [],
    this.vpnActive = false,
    this.isLoading = false,
  });

  BlockingState copyWith({
    List<BlockedSite>? sites,
    bool? vpnActive,
    bool? isLoading,
  }) => BlockingState(
    sites: sites ?? this.sites,
    vpnActive: vpnActive ?? this.vpnActive,
    isLoading: isLoading ?? this.isLoading,
  );
}

// ── Notifier ─────────────────────────────────────────────────────────────

class BlockingNotifier extends StateNotifier<BlockingState> {
  BlockingNotifier() : super(const BlockingState()) {
    _load();
  }

  static const _vpnChannel = MethodChannel(AppConstants.channelVpn);

  // Load from local storage
  void _load() {
    final storage = LocalStorage.instance;
    final sites = storage.getBlockedSites();
    final vpnActive = storage.getBool(AppConstants.keyVpnEnabled);
    state = state.copyWith(sites: sites, vpnActive: vpnActive);
  }

  // ── VPN ──────────────────────────────────────────────────────────────────

  Future<bool> toggleVpn() async {
    final target = !state.vpnActive;
    try {
      if (target) {
        await _startVpn();
      } else {
        await _stopVpn();
      }
      state = state.copyWith(vpnActive: target);
      await LocalStorage.instance.setBool(AppConstants.keyVpnEnabled, target);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startVpn() async {
    final activeDomains = state.sites
        .where((s) => s.isActive)
        .map((s) => s.domain)
        .toList();
    try {
      await _vpnChannel.invokeMethod('startVpn', {'domains': activeDomains});
    } on PlatformException catch (_) {
      // Silently ignore on non-Android platforms
    }
  }

  Future<void> _stopVpn() async {
    try {
      await _vpnChannel.invokeMethod('stopVpn');
    } on PlatformException catch (_) {}
  }

  // ── Sites CRUD ───────────────────────────────────────────────────────────

  Future<void> addSite(String domain, {String? category}) async {
    final site = BlockedSite(
      domain: domain.toLowerCase().trim(),
      category: category,
      isActive: true,
    );
    final storage = LocalStorage.instance;
    await storage.upsertBlockedSite(site);
    _load();
    if (state.vpnActive) await _startVpn(); // refresh VPN rules
  }

  Future<void> toggleSite(BlockedSite site) async {
    final updated = site.copyWith(isActive: !site.isActive);
    await LocalStorage.instance.upsertBlockedSite(updated);
    _load();
    if (state.vpnActive) await _startVpn();
  }

  Future<void> deleteSite(String id) async {
    await LocalStorage.instance.deleteBlockedSite(id);
    _load();
    if (state.vpnActive) await _startVpn();
  }

  Future<void> activateCategory(String category, bool active) async {
    final sites = state.sites.map((s) {
      if (s.category == category) return s.copyWith(isActive: active);
      return s;
    }).toList();
    await LocalStorage.instance.saveBlockedSites(sites);
    _load();
    if (state.vpnActive) await _startVpn();
  }

  // Active site list for quick access
  List<BlockedSite> get activeSites =>
      state.sites.where((s) => s.isActive).toList();
}

// ── Provider ─────────────────────────────────────────────────────────────

final blockingProvider = StateNotifierProvider<BlockingNotifier, BlockingState>(
  (ref) => BlockingNotifier(),
);
