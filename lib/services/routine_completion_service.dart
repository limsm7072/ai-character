import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/routine_completion.dart';

class RoutineCompletionService {
  static const _key = 'routine_completions';
  final SharedPreferences _prefs;

  RoutineCompletionService(this._prefs);

  List<RoutineCompletion> _getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => RoutineCompletion.fromJson(e)).toList();
  }

  Future<void> _saveAll(List<RoutineCompletion> completions) async {
    await _prefs.setString(
        _key, jsonEncode(completions.map((c) => c.toJson()).toList()));
  }

  /// Toggle completion for a routine on a given date.
  /// Returns true if now completed, false if unchecked.
  Future<bool> toggleCompletion(String routineId, String date) async {
    final all = _getAll();
    final idx = all.indexWhere(
        (c) => c.routineId == routineId && c.date == date);

    if (idx >= 0) {
      all.removeAt(idx);
      await _saveAll(all);
      return false;
    } else {
      all.add(RoutineCompletion(
        routineId: routineId,
        date: date,
        completedAt: DateTime.now().millisecondsSinceEpoch,
      ));
      await _saveAll(all);
      return true;
    }
  }

  /// Check if a routine is completed on a given date.
  bool isCompleted(String routineId, String date) {
    return _getAll()
        .any((c) => c.routineId == routineId && c.date == date);
  }

  /// Get completion rate for a routine over the last N days (0.0 ~ 1.0).
  double getCompletionRate(String routineId, int days) {
    if (days <= 0) return 0.0;
    final now = DateTime.now();
    final all = _getAll().where((c) => c.routineId == routineId).toList();
    int completed = 0;

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _formatDate(date);
      if (all.any((c) => c.date == dateStr)) {
        completed++;
      }
    }

    return completed / days;
  }

  /// Get all completions for a specific date.
  List<RoutineCompletion> getCompletionsByDate(String date) {
    return _getAll().where((c) => c.date == date).toList();
  }

  /// Get today's date string.
  String todayStr() => _formatDate(DateTime.now());

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
