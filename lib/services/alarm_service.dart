import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm.dart';

class AlarmService {
  static const _key = 'alarms_data';
  static const _counterKey = 'alarm_notif_counter';
  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');
  final SharedPreferences _prefs;
  List<Alarm> _alarms = [];

  AlarmService(this._prefs) {
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
  }

  Future<void> _scheduleAlarm(Alarm alarm) async {
    final baseId = alarm.notificationId;

    if (alarm.isOneTime) {
      final now = DateTime.now();
      var target = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      try {
        await _channel.invokeMethod('scheduleNativeAlarm', {
          'requestCode': baseId,
          'timeMillis': target.millisecondsSinceEpoch,
          'alarmId': alarm.id,
          'label': alarm.label,
          'repeating': false,
        });
      } catch (e) {
        print('[AlarmService] scheduleNativeAlarm error: $e');
      }
    } else {
      for (int i = 0; i < 7; i++) {
        if (alarm.activeDays[i]) {
          final dayOfWeek = i + 1; // 1=Mon ... 7=Sun
          final target = _nextDayOfWeek(dayOfWeek, alarm.hour, alarm.minute);
          try {
            await _channel.invokeMethod('scheduleNativeAlarm', {
              'requestCode': baseId + i,
              'timeMillis': target.millisecondsSinceEpoch,
              'alarmId': alarm.id,
              'label': alarm.label,
              'repeating': true,
            });
          } catch (e) {
            print('[AlarmService] scheduleNativeAlarm error: $e');
          }
        } else {
          // Cancel this day if it was previously scheduled
          try {
            await _channel.invokeMethod('cancelNativeAlarm', {
              'requestCode': baseId + i,
            });
          } catch (_) {}
        }
      }
    }
  }

  DateTime _nextDayOfWeek(int dayOfWeek, int hour, int minute) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    while (target.weekday != dayOfWeek) {
      target = target.add(const Duration(days: 1));
    }
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 7));
    }
    return target;
  }

  Future<void> _cancelAlarm(Alarm alarm) async {
    final baseId = alarm.notificationId;
    for (int i = 0; i < 8; i++) {
      try {
        await _channel.invokeMethod('cancelNativeAlarm', {
          'requestCode': baseId + i,
        });
      } catch (_) {}
    }
  }

  /// Stop alarm ring service (called when user dismisses alarm)
  static Future<void> stopAlarmRing() async {
    try {
      await _channel.invokeMethod('stopAlarmRing');
    } catch (_) {}
  }
}
