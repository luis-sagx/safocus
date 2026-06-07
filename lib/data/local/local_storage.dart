import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/blocked_sites.dart';
import '../../core/constants/motivational_phrases.dart';
import '../models/app_category.dart';
import '../models/app_limit.dart';
import '../models/blocked_site.dart';
import '../models/motivational_phrase.dart';
import '../models/usage_stat.dart';

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
    await ls._migrateCategoryLimits();
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

  // ── Migration: per‑app limits → category‑based limits ────────────────────

  /// Idempotent migration that groups old [AppLimit] entries by their
  /// `dailyLimitMinutes` value, creates one "Uncategorized" category per
  /// distinct limit, and assigns apps to those categories.
  Future<void> _migrateCategoryLimits() async {
    final migrated = _prefs.getBool(AppConstants.keyCategoriesMigrated) ??
        false;
    if (migrated) return;

    final rawLimits = _prefs.getStringList('app_limits') ?? [];
    if (rawLimits.isEmpty) {
      await _prefs.setBool(AppConstants.keyCategoriesMigrated, true);
      return;
    }

    // Parse old entries and group by dailyLimitMinutes.
    final Map<int, List<Map<String, dynamic>>> groups = {};
    for (final raw in rawLimits) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final limit = json['dailyLimitMinutes'] as int? ?? 0;
        groups.putIfAbsent(limit, () => []).add(json);
      } catch (_) {
        // Skip corrupted entries.
      }
    }

    if (groups.isEmpty) {
      await _prefs.setBool(AppConstants.keyCategoriesMigrated, true);
      return;
    }

    final now = DateTime.now();
    final newCategories = <AppCategory>[];
    final migratedLimits = <AppLimit>[];

    for (final entry in groups.entries) {
      final limitMinutes = entry.key;
      final apps = entry.value;

      // Build a descriptive "Uncategorized" category name.
      final category = AppCategory(
        name: limitMinutes > 0
            ? 'Uncategorized (${limitMinutes}min)'
            : 'Uncategorized',
        color: '#9E9E9E',
        emoji: '📦',
        dailyLimitMinutes: limitMinutes,
        isPredefined: false,
        createdAt: now,
      );
      newCategories.add(category);

      for (final appJson in apps) {
        migratedLimits.add(AppLimit(
          id: appJson['id'] as String?,
          packageName: appJson['packageName'] as String,
          appName: appJson['appName'] as String,
          categoryId: category.id,
          effectiveLimitMinutes: limitMinutes,
          usedMinutesToday: appJson['usedMinutesToday'] as int? ?? 0,
          isActive: appJson['isActive'] as bool? ?? true,
          emergencyExtUsedToday:
              appJson['emergencyExtUsedToday'] as bool? ?? false,
          createdAt: appJson['createdAt'] != null
              ? DateTime.parse(appJson['createdAt'] as String)
              : now,
        ));
      }
    }

    // Persist categories (merge with any existing ones).
    final existingCategories = getAppCategories(seed: false);
    existingCategories.addAll(newCategories);
    await saveAppCategories(existingCategories);

    // Persist migrated limits.
    await saveAppLimits(migratedLimits);

    await _prefs.setBool(AppConstants.keyCategoriesMigrated, true);
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

  // ── App Categories ────────────────────────────────────────────────────────

  List<AppCategory> getAppCategories({bool seed = true}) {
    final raw = _prefs.getStringList('app_categories');
    if (raw == null || raw.isEmpty) {
      if (seed) {
        final predefined = _buildPredefinedCategories();
        saveAppCategories(predefined);
        return predefined;
      }
      return [];
    }
    return raw
        .map(
          (s) =>
              AppCategory.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> saveAppCategories(List<AppCategory> categories) async {
    final encoded =
        categories.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList('app_categories', encoded);
  }

  Future<void> upsertAppCategory(AppCategory category) async {
    final categories = getAppCategories(seed: false);
    final idx = categories.indexWhere((c) => c.id == category.id);
    if (idx == -1) {
      categories.add(category);
    } else {
      categories[idx] = category;
    }
    await saveAppCategories(categories);
  }

  Future<void> deleteAppCategory(String id) async {
    final categories = getAppCategories(seed: false)
      ..removeWhere((c) => c.id == id);
    await saveAppCategories(categories);
  }

  List<AppCategory> _buildPredefinedCategories() {
    final now = DateTime.now();
    return AppConstants.predefinedCategories.map((def) {
      return AppCategory(
        id: const Uuid().v4(),
        name: def['nameEn'] as String,
        color: def['color'] as String,
        emoji: def['emoji'] as String? ?? '📦',
        iconName: def['iconName'] as String?,
        dailyLimitMinutes: def['dailyLimitMinutes'] as int,
        isPredefined: true,
        createdAt: now,
      );
    }).toList();
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

  Future<void> upsertUsageStat(DailyUsageStat stat) async {
    final stats = getUsageStats();
    stats.removeWhere(
      (s) =>
          s.packageName == stat.packageName &&
          s.date.year == stat.date.year &&
          s.date.month == stat.date.month &&
          s.date.day == stat.date.day,
    );
    stats.add(stat);
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
    final list = getBlockAttempts();
    // Prevent adding exact duplicate attempts (same timestamp + domain or same id)
    final exists = list.any(
      (a) =>
          a.id == attempt.id ||
          (a.domain == attempt.domain && a.timestamp == attempt.timestamp),
    );
    if (!exists) {
      // Additionally, ignore rapid repeated attempts to the same domain
      // (e.g., multiple resource requests) within a short window.
      BlockAttempt? lastSame;
      for (final a in list) {
        if (a.domain == attempt.domain) {
          if (lastSame == null || a.timestamp.isAfter(lastSame.timestamp)) {
            lastSame = a;
          }
        }
      }
      if (lastSame != null) {
        final diff =
            attempt.timestamp.difference(lastSame.timestamp).inSeconds.abs();
        if (diff <= 5) {
          return; // skip near-duplicate within 5 seconds
        }
      }
      list.add(attempt);
    } else {
      return; // skip saving if duplicate
    }
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
