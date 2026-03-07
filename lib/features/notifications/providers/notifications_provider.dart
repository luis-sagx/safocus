import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/local_storage.dart';
import '../../../data/models/motivational_phrase.dart';
import '../services/notification_service.dart';
import '../../settings/providers/settings_provider.dart';

class NotificationsState {
  final List<MotivationalPhrase> phrases;
  final int intervalHours;
  final bool enabled;

  const NotificationsState({
    this.phrases = const [],
    this.intervalHours = 2,
    this.enabled = true,
  });

  NotificationsState copyWith({
    List<MotivationalPhrase>? phrases,
    int? intervalHours,
    bool? enabled,
  }) => NotificationsState(
    phrases: phrases ?? this.phrases,
    intervalHours: intervalHours ?? this.intervalHours,
    enabled: enabled ?? this.enabled,
  );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._ref) : super(const NotificationsState()) {
    _load();
  }

  final Ref _ref;

  void _load() {
    final storage = LocalStorage.instance;
    final phrases = storage.getPhrases();
    final interval = storage.getInt('notif_interval_hours', defaultValue: 2);
    final enabled = storage.getBool('notif_enabled', defaultValue: true);
    state = NotificationsState(
      phrases: phrases,
      intervalHours: interval,
      enabled: enabled,
    );
  }

  Future<void> addPhrase(String text, String lang) async {
    final phrase = MotivationalPhrase(text: text, lang: lang);
    await LocalStorage.instance.upsertPhrase(phrase);
    _load();
    await _reschedule();
  }

  Future<void> deletePhrase(String id) async {
    await LocalStorage.instance.deletePhrase(id);
    _load();
    await _reschedule();
  }

  Future<void> togglePhrase(MotivationalPhrase phrase) async {
    final updated = phrase.copyWith(isActive: !phrase.isActive);
    await LocalStorage.instance.upsertPhrase(updated);
    _load();
    await _reschedule();
  }

  Future<void> setInterval(int hours) async {
    await LocalStorage.instance.setInt('notif_interval_hours', hours);
    state = state.copyWith(intervalHours: hours);
    await _reschedule();
  }

  Future<void> setEnabled(bool enabled) async {
    await LocalStorage.instance.setBool('notif_enabled', enabled);
    state = state.copyWith(enabled: enabled);
    if (!enabled) {
      await NotificationService.instance.cancelAllMotivational();
    } else {
      await _reschedule();
    }
  }

  Future<void> _reschedule() async {
    if (!state.enabled) return;
    final settings = _ref.read(settingsProvider);
    await NotificationService.instance.scheduleMotivational(
      phrases: state.phrases,
      intervalHours: state.intervalHours,
      quietStartHour: settings.quietStartHour,
      quietEndHour: settings.quietEndHour,
    );
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
      (ref) => NotificationsNotifier(ref),
    );
