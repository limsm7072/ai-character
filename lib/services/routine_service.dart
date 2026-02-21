import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/routine.dart';
import 'notification_service.dart';

/// Manages routine CRUD operations and persistence.
class RoutineService {
  static const _key = 'routines';
  final SharedPreferences _prefs;
  final NotificationService? _notification;

  RoutineService(this._prefs, [this._notification]);

  List<Routine> getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Routine.fromJson(e)).toList();
  }

  Future<void> saveAll(List<Routine> routines) async {
    final json = jsonEncode(routines.map((r) => r.toJson()).toList());
    await _prefs.setString(_key, json);
  }

  Future<void> add(Routine routine) async {
    final routines = getAll();
    routines.add(routine);
    await saveAll(routines);
    await _syncNotification(routine);
  }

  Future<void> update(Routine routine) async {
    final routines = getAll();
    final index = routines.indexWhere((r) => r.id == routine.id);
    if (index >= 0) {
      routines[index] = routine;
      await saveAll(routines);
      await _syncNotification(routine);
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final routines = getAll();
    if (newIndex > oldIndex) newIndex--;
    final item = routines.removeAt(oldIndex);
    routines.insert(newIndex, item);
    await saveAll(routines);
  }

  Future<void> delete(String id) async {
    final routines = getAll();
    final routine = routines.firstWhere((r) => r.id == id, orElse: () => routines.first);
    await _cancelNotification(routine);
    routines.removeWhere((r) => r.id == id);
    await saveAll(routines);
  }

  /// Rearranges routines so that the given IDs appear contiguously,
  /// placed at the position of the first selected routine.
  Future<void> makeContiguous(List<String> ids) async {
    final routines = getAll();
    final idSet = ids.toSet();
    // Find the index of the first selected routine
    final firstIdx = routines.indexWhere((r) => idSet.contains(r.id));
    if (firstIdx < 0) return;

    final selected = routines.where((r) => idSet.contains(r.id)).toList();
    routines.removeWhere((r) => idSet.contains(r.id));
    // Clamp in case removals shifted things
    final insertAt = firstIdx.clamp(0, routines.length);
    routines.insertAll(insertAt, selected);
    await saveAll(routines);
  }

  /// Returns the currently active routine, if any.
  Routine? getActiveRoutine() {
    final routines = getAll();
    for (final r in routines) {
      if (r.isActiveNow()) return r;
    }
    return null;
  }

  /// Reschedule all routine notifications (call on app start).
  Future<void> rescheduleAllNotifications() async {
    final routines = getAll();
    for (final r in routines) {
      await _syncNotification(r);
    }
  }

  // ─── Notification Scheduling ─────────────────────

  int _notificationBaseId(String routineId) =>
      NotificationService.routineBase + (routineId.hashCode.abs() % 9000);

  Future<void> _syncNotification(Routine routine) async {
    if (_notification == null) return;
    await _cancelNotification(routine);
    if (routine.linkedAlarmId == null || !routine.isEnabled) return;

    final baseId = _notificationBaseId(routine.id);
    final hasActiveDays = routine.activeDays.any((d) => d);

    if (!hasActiveDays) {
      // No active days — one-time notification
      final now = DateTime.now();
      var target = DateTime(now.year, now.month, now.day, routine.startTime.hour, routine.startTime.minute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      await _notification!.scheduleExact(
        id: baseId,
        title: routine.name,
        body: '${routine.name} 시작할 시간이야!',
        dateTime: target,
        channelId: NotificationService.routineChannelId,
        channelName: '일정 알림',
      );
    } else {
      // Weekly: schedule for each active day
      for (int i = 0; i < 7; i++) {
        if (routine.activeDays[i]) {
          await _notification!.scheduleWeekly(
            id: baseId + i,
            title: routine.name,
            body: '${routine.name} 시작할 시간이야!',
            hour: routine.startTime.hour,
            minute: routine.startTime.minute,
            dayOfWeek: i + 1, // 1=Mon ... 7=Sun
            channelId: NotificationService.routineChannelId,
            channelName: '일정 알림',
          );
        }
      }
    }
  }

  Future<void> _cancelNotification(Routine routine) async {
    if (_notification == null) return;
    final baseId = _notificationBaseId(routine.id);
    for (int i = 0; i < 7; i++) {
      await _notification!.cancel(baseId + i);
    }
  }
}
