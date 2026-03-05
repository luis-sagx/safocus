import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/blocked_site.dart';
import '../models/app_limit.dart';
import '../models/motivational_phrase.dart';
import '../models/usage_stat.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/blocked_sites.dart';
import '../../core/constants/motivational_phrases.dart';

/// Simple JSON-based persistence on top of SharedPreferences.
/// Replaces Hive to avoid build_runner requirement in v1.
class LocalStorage {
  static LocalStorage? _instance;
  late SharedPreferences _prefs;

  LocalStorage._();

  static LocalStorage get instance => _instance!;

  static Future<LocalStorage> init() async {
    final ls = LocalStorage._();
    ls._prefs = await SharedPreferences.getInstance();
    await ls._seedDefaults();
    _instance = ls;
    return ls;
  }

  // ── Seed on first run ────────────────────────────────────────────────────

  Future<void> _seedDefaults() async {
    final seeded = _prefs.getBool('_defaults_seeded') ?? false;
    if (seeded) return;

    // Seed default blocked sites
    final sites = <BlockedSite>[];
    BlockedSites.defaultByCategory.forEach((category, domains) {
      for (final domain in domains) {
        sites.add(
          BlockedSite(
            domain: domain,
            category: category,
            isDefault: true,
            isActive: false, // user opts-in
          ),
        );
      }
    });
    await saveBlockedSites(sites);

    // Seed motivational phrases
    final phrases =
        MotivationalPhrases.defaults
            .map(
              (m) => MotivationalPhrase(
                text: m['text']!,
                lang: m['lang']!,
                isDefault: true,
              ),
            )
            .toList();
    await savePhrases(phrases);

    await _prefs.setBool('_defaults_seeded', true);
  }

  // ── Blocked Sites ────────────────────────────────────────────────────────

  List<BlockedSite> getBlockedSites() {
    final raw = _prefs.getStringList('blocked_sites') ?? [];
    return raw
        .map((s) => BlockedSite.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveBlockedSites(List<BlockedSite> sites) async {
    final encoded = sites.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs.setStringList('blocked_sites', encoded);
  }

  Future<void> upsertBlockedSite(BlockedSite site) async {
    final sites = getBlockedSites();
    final idx = sites.indexWhere((s) => s.id == site.id);
    if (idx == -1) {
      sites.add(site);
    } else {
      sites[idx] = site;
    }
    await saveBlockedSites(sites);
  }

  Future<void> deleteBlockedSite(String id) async {
    final sites = getBlockedSites()..removeWhere((s) => s.id == id);
    await saveBlockedSites(sites);
  }

  // ── App Limits ───────────────────────────────────────────────────────────

  List<AppLimit> getAppLimits() {
    final raw = _prefs.getStringList('app_limits') ?? [];
    return raw
        .map((s) => AppLimit.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAppLimits(List<AppLimit> limits) async {
    final encoded = limits.map((l) => jsonEncode(l.toJson())).toList();
    await _prefs.setStringList('app_limits', encoded);
  }

  Future<void> upsertAppLimit(AppLimit limit) async {
    final limits = getAppLimits();
    final idx = limits.indexWhere((l) => l.id == limit.id);
    if (idx == -1) {
      limits.add(limit);
    } else {
      limits[idx] = limit;
    }
    await saveAppLimits(limits);
  }

  Future<void> deleteAppLimit(String id) async {
    final limits = getAppLimits()..removeWhere((l) => l.id == id);
    await saveAppLimits(limits);
  }

  // ── Motivational Phrases ─────────────────────────────────────────────────

  List<MotivationalPhrase> getPhrases() {
    final raw = _prefs.getStringList('phrases') ?? [];
    return raw
        .map(
          (s) => MotivationalPhrase.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> savePhrases(List<MotivationalPhrase> phrases) async {
    final encoded = phrases.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList('phrases', encoded);
  }

  Future<void> upsertPhrase(MotivationalPhrase phrase) async {
    final phrases = getPhrases();
    final idx = phrases.indexWhere((p) => p.id == phrase.id);
    if (idx == -1) {
      phrases.add(phrase);
    } else {
      phrases[idx] = phrase;
    }
    await savePhrases(phrases);
  }

  Future<void> deletePhrase(String id) async {
    final phrases = getPhrases()..removeWhere((p) => p.id == id);
    await savePhrases(phrases);
  }

  // ── Usage Stats ──────────────────────────────────────────────────────────

  List<DailyUsageStat> getUsageStats() {
    final raw = _prefs.getStringList('usage_stats') ?? [];
    return raw
        .map(
          (s) => DailyUsageStat.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> saveUsageStats(List<DailyUsageStat> stats) async {
    final encoded = stats.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs.setStringList('usage_stats', encoded);
  }

  Future<void> addUsageStat(DailyUsageStat stat) async {
    final stats = getUsageStats()..add(stat);
    await saveUsageStats(stats);
  }

  // ── Block Attempts ───────────────────────────────────────────────────────

  List<BlockAttempt> getBlockAttempts() {
    final raw = _prefs.getStringList('block_attempts') ?? [];
    return raw
        .map(
          (s) => BlockAttempt.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> addBlockAttempt(BlockAttempt attempt) async {
    final list = getBlockAttempts()..add(attempt);
    // Keep only last 500 entries
    if (list.length > 500) list.removeRange(0, list.length - 500);
    final encoded = list.map((a) => jsonEncode(a.toJson())).toList();
    await _prefs.setStringList('block_attempts', encoded);
  }

  Future<void> clearBlockAttempts() async {
    await _prefs.remove('block_attempts');
  }

  // ── Generic settings wrappers ────────────────────────────────────────────

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  String? getString(String key) => _prefs.getString(key);

  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  int getInt(String key, {int defaultValue = 0}) =>
      _prefs.getInt(key) ?? defaultValue;

  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> clear() => _prefs.clear();
}
