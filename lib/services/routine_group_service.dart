import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/routine_group.dart';

class RoutineGroupService {
  static const _key = 'routine_groups';
  final SharedPreferences _prefs;

  RoutineGroupService(this._prefs);

  List<RoutineGroup> getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => RoutineGroup.fromJson(e)).toList();
  }

  Future<void> saveAll(List<RoutineGroup> groups) async {
    final json = jsonEncode(groups.map((g) => g.toJson()).toList());
    await _prefs.setString(_key, json);
  }

  Future<RoutineGroup> createGroup(List<String> routineIds) async {
    final groups = getAll();
    // Remove selected routines from existing groups
    for (final g in groups) {
      g.routineIds.removeWhere((id) => routineIds.contains(id));
    }
    // Remove groups that became too small
    groups.removeWhere((g) => g.routineIds.length < 2);

    final group = RoutineGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      routineIds: routineIds,
    );
    groups.add(group);
    await saveAll(groups);
    return group;
  }

  Future<void> ungroup(String groupId) async {
    final groups = getAll();
    groups.removeWhere((g) => g.id == groupId);
    await saveAll(groups);
  }

  Future<void> onRoutineDeleted(String routineId) async {
    final groups = getAll();
    for (final g in groups) {
      g.routineIds.remove(routineId);
    }
    // Remove groups with fewer than 2 members
    groups.removeWhere((g) => g.routineIds.length < 2);
    await saveAll(groups);
  }

  /// Find the group that contains this routine, if any.
  RoutineGroup? groupForRoutine(String routineId) {
    final groups = getAll();
    for (final g in groups) {
      if (g.routineIds.contains(routineId)) return g;
    }
    return null;
  }
}
