import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/distraction_log.dart';

class DistractionLogService {
  static const _key = 'distraction_logs';
  final SharedPreferences _prefs;

  DistractionLogService(this._prefs);

  List<DistractionLog> getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => DistractionLog.fromJson(e)).toList();
  }

  List<DistractionLog> getByRoutine(String routineId) {
    return getAll().where((l) => l.routineId == routineId).toList();
  }

  List<DistractionLog> getByDate(String date) {
    return getAll().where((l) => l.date == date).toList();
  }

  List<DistractionLog> getByRoutineAndDate(String routineId, String date) {
    return getAll()
        .where((l) => l.routineId == routineId && l.date == date)
        .toList();
  }

  RoutineStats getRoutineStats(String routineId, {String? date}) {
    final logs = date != null
        ? getByRoutineAndDate(routineId, date)
        : getByRoutine(routineId);

    final appBreakdown = <String, AppDistractionInfo>{};
    var totalTime = Duration.zero;

    for (final log in logs) {
      totalTime += log.duration;
      final info = appBreakdown.putIfAbsent(
        log.appPackage,
        () => AppDistractionInfo(
          appLabel: log.appLabel,
          appPackage: log.appPackage,
        ),
      );
      info.count++;
      info.totalTime += log.duration;
    }

    return RoutineStats(
      routineId: routineId,
      routineName: logs.isNotEmpty ? logs.first.routineName : '',
      totalDistractions: logs.length,
      totalTime: totalTime,
      appBreakdown: appBreakdown,
    );
  }

  /// Get stats grouped by date for a routine
  Map<String, RoutineStats> getRoutineStatsByDate(String routineId) {
    final logs = getByRoutine(routineId);
    final grouped = <String, List<DistractionLog>>{};

    for (final log in logs) {
      grouped.putIfAbsent(log.date, () => []).add(log);
    }

    return grouped.map((date, dateLogs) {
      final appBreakdown = <String, AppDistractionInfo>{};
      var totalTime = Duration.zero;

      for (final log in dateLogs) {
        totalTime += log.duration;
        final info = appBreakdown.putIfAbsent(
          log.appPackage,
          () => AppDistractionInfo(
            appLabel: log.appLabel,
            appPackage: log.appPackage,
          ),
        );
        info.count++;
        info.totalTime += log.duration;
      }

      return MapEntry(
        date,
        RoutineStats(
          routineId: routineId,
          routineName: dateLogs.first.routineName,
          totalDistractions: dateLogs.length,
          totalTime: totalTime,
          appBreakdown: appBreakdown,
        ),
      );
    });
  }

  Future<void> clearAll() async {
    await _prefs.remove(_key);
  }

  Future<void> clearByRoutine(String routineId) async {
    final logs = getAll();
    logs.removeWhere((l) => l.routineId == routineId);
    await _prefs.setString(_key, jsonEncode(logs.map((l) => l.toJson()).toList()));
  }
}
