import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm.dart';
import 'notification_service.dart';

class AlarmService {
  static const _key = 'alarms_data';
  static const _counterKey = 'alarm_notif_counter';
  final SharedPreferences _prefs;
  final NotificationService _notification;
  List<Alarm> _alarms = [];

  AlarmService(this._prefs, this._notification) {
    _load();
  }

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      _alarms = Alarm.decode(raw);
      _migrateNotifIds();
    }
  }

  /// Assign notifBaseId to alarms that don't have one (migration).
  void _migrateNotifIds() {
    bool changed = false;
    for (final alarm in _alarms) {
      if (alarm.notifBaseId == null) {
        alarm.notifBaseId = _nextNotifBaseId();
        changed = true;
      }
    }
    if (changed) _save();
  }

  int _nextNotifBaseId() {
    // Find max existing notifBaseId across all alarms
    int maxId = _prefs.getInt(_counterKey) ?? 0;
    for (final a in _alarms) {
      if (a.notifBaseId != null && a.notifBaseId! >= maxId) {
        maxId = a.notifBaseId! + 1;
      }
    }
    _prefs.setInt(_counterKey, maxId + 1);
    return maxId;
  }

  Future<void> _save() async {
    await _prefs.setString(_key, Alarm.encode(_alarms));
  }

  List<Alarm> getAll() => List.unmodifiable(_alarms);

  Alarm? getById(String id) {
    final matches = _alarms.where((a) => a.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  int get enabledCount => _alarms.where((a) => a.isEnabled).length;

  Future<Alarm> add(Alarm alarm) async {
    alarm.notifBaseId ??= _nextNotifBaseId();
    _alarms.add(alarm);
    await _save();
    if (alarm.isEnabled) await _scheduleAlarm(alarm);
    return alarm;
  }

  Future<void> update(Alarm alarm) async {
    final idx = _alarms.indexWhere((a) => a.id == alarm.id);
    if (idx >= 0) {
      _alarms[idx] = alarm;
      await _save();
      await _cancelAlarm(alarm);
      if (alarm.isEnabled) await _scheduleAlarm(alarm);
    }
  }

  Future<void> delete(String id) async {
    final alarm = _alarms.firstWhere((a) => a.id == id, orElse: () => throw Exception('Not found'));
    await _cancelAlarm(alarm);
    _alarms.removeWhere((a) => a.id == id);
    await _save();
  }

  Future<void> toggleEnabled(String id) async {
    final alarm = _alarms.firstWhere((a) => a.id == id);
    alarm.isEnabled = !alarm.isEnabled;
    await _save();
    if (alarm.isEnabled) {
      await _scheduleAlarm(alarm);
    } else {
      await _cancelAlarm(alarm);
    }
  }

  Future<void> rescheduleAll() async {
    print('[AlarmService] rescheduleAll: ${_alarms.length} alarms, ${_alarms.where((a) => a.isEnabled).length} enabled');
    for (final alarm in _alarms) {
      if (alarm.isEnabled) await _scheduleAlarm(alarm);
    }
    // Debug: print pending notifications
    final pending = await _notification.getPendingNotifications();
    final alarmPending = pending.where((p) => p.id >= 10000 && p.id < 20000).toList();
    print('[AlarmService] pending alarm notifications: ${alarmPending.length}');
    for (final p in alarmPending) {
      print('  - id=${p.id} title=${p.title} body=${p.body}');
    }
  }

  Future<void> _scheduleAlarm(Alarm alarm) async {
    final baseId = alarm.notificationId;
    final payload = 'alarm:${alarm.id}';

    if (alarm.isOneTime) {
      // One-time alarm: schedule for the next occurrence
      final now = DateTime.now();
      var target = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      await _notification.scheduleExact(
        id: baseId,
        title: '알람',
        body: alarm.label,
        dateTime: target,
        channelId: NotificationService.alarmChannelId,
        channelName: '알람',
        payload: payload,
      );
    } else {
      // Weekly repeating: schedule for each active day
      for (int i = 0; i < 7; i++) {
        if (alarm.activeDays[i]) {
          final dayOfWeek = i + 1; // 1=Mon ... 7=Sun (ISO)
          await _notification.scheduleWeekly(
            id: baseId + i,
            title: '알람',
            body: alarm.label,
            hour: alarm.hour,
            minute: alarm.minute,
            dayOfWeek: dayOfWeek,
            channelId: NotificationService.alarmChannelId,
            channelName: '알람',
            payload: payload,
          );
        }
      }
    }
  }

  Future<void> _cancelAlarm(Alarm alarm) async {
    final baseId = alarm.notificationId;
    // Cancel all possible notification IDs for this alarm
    for (int i = 0; i < 7; i++) {
      await _notification.cancel(baseId + i);
    }
  }
}
