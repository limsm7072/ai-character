import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/routine.dart';

/// Manages routine CRUD operations and persistence.
class RoutineService {
  static const _key = 'routines';
  final SharedPreferences _prefs;

  RoutineService(this._prefs);

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
  }

  Future<void> update(Routine routine) async {
    final routines = getAll();
    final index = routines.indexWhere((r) => r.id == routine.id);
    if (index >= 0) {
      routines[index] = routine;
      await saveAll(routines);
    }
  }

  Future<void> delete(String id) async {
    final routines = getAll();
    routines.removeWhere((r) => r.id == id);
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
}
