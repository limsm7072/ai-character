import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/goal.dart';
import '../models/todo.dart';
import 'routine_completion_service.dart';
import 'todo_service.dart';

class GoalService {
  static const _key = 'goals';
  final SharedPreferences _prefs;

  GoalService(this._prefs);

  // ─── READ ───────────────────────────────────────
  List<Goal> getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Goal.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Goal? getById(String id) {
    return getAll().where((g) => g.id == id).firstOrNull;
  }

  List<Goal> getIncomplete() =>
      getAll().where((g) => !g.isCompleted).toList();

  List<Goal> getCompleted() =>
      getAll().where((g) => g.isCompleted).toList();

  List<Goal> getByCategory(String category) =>
      getAll().where((g) => g.category == category).toList();

  int get incompleteCount => getIncomplete().length;

  // ─── WRITE ──────────────────────────────────────
  Future<void> _saveAll(List<Goal> goals) async {
    await _prefs.setString(_key, jsonEncode(goals.map((g) => g.toJson()).toList()));
  }

  Future<Goal> add(String title, {
    String description = '',
    String category = '기타',
    String? targetDate,
  }) async {
    final goals = getAll();
    final now = DateTime.now().millisecondsSinceEpoch;
    final goal = Goal(
      id: now.toString(),
      title: title,
      description: description,
      category: category,
      targetDate: targetDate,
      createdAt: now,
    );
    goals.add(goal);
    await _saveAll(goals);
    return goal;
  }

  Future<void> update(Goal goal) async {
    final goals = getAll();
    final idx = goals.indexWhere((g) => g.id == goal.id);
    if (idx >= 0) {
      goals[idx] = goal;
      await _saveAll(goals);
    }
  }

  Future<void> delete(String id) async {
    final goals = getAll();
    goals.removeWhere((g) => g.id == id);
    await _saveAll(goals);
  }

  Future<void> toggleComplete(String id) async {
    final goals = getAll();
    final idx = goals.indexWhere((g) => g.id == id);
    if (idx >= 0) {
      goals[idx].isCompleted = !goals[idx].isCompleted;
      goals[idx].completedAt = goals[idx].isCompleted
          ? DateTime.now().millisecondsSinceEpoch
          : null;
      await _saveAll(goals);
    }
  }

  // ─── MILESTONE ──────────────────────────────────
  Future<void> addMilestone(String goalId, String title) async {
    final goals = getAll();
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx >= 0) {
      goals[idx].milestones.add(Milestone(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
      ));
      await _saveAll(goals);
    }
  }

  Future<void> removeMilestone(String goalId, String milestoneId) async {
    final goals = getAll();
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx >= 0) {
      goals[idx].milestones.removeWhere((m) => m.id == milestoneId);
      await _saveAll(goals);
    }
  }

  Future<void> toggleMilestone(String goalId, String milestoneId) async {
    final goals = getAll();
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx >= 0) {
      final mIdx = goals[idx].milestones.indexWhere((m) => m.id == milestoneId);
      if (mIdx >= 0) {
        final m = goals[idx].milestones[mIdx];
        m.isCompleted = !m.isCompleted;
        m.completedAt = m.isCompleted ? DateTime.now().millisecondsSinceEpoch : null;
        await _saveAll(goals);
      }
    }
  }

  // ─── LINK/UNLINK ────────────────────────────────
  Future<void> linkRoutine(String goalId, String routineId) async {
    final goals = getAll();
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx >= 0 && !goals[idx].linkedRoutineIds.contains(routineId)) {
      goals[idx].linkedRoutineIds.add(routineId);
      await _saveAll(goals);
    }
  }

  Future<void> unlinkRoutine(String goalId, String routineId) async {
    final goals = getAll();
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx >= 0) {
      goals[idx].linkedRoutineIds.remove(routineId);
      await _saveAll(goals);
    }
  }

  Future<void> linkTodo(String goalId, String todoId) async {
    final goals = getAll();
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx >= 0 && !goals[idx].linkedTodoIds.contains(todoId)) {
      goals[idx].linkedTodoIds.add(todoId);
      await _saveAll(goals);
    }
  }

  Future<void> unlinkTodo(String goalId, String todoId) async {
    final goals = getAll();
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx >= 0) {
      goals[idx].linkedTodoIds.remove(todoId);
      await _saveAll(goals);
    }
  }

  // ─── PROGRESS ───────────────────────────────────
  /// 개별 목표 진행률 (0.0 ~ 1.0)
  double getProgress(Goal goal, RoutineCompletionService completionService, TodoService todoService) {
    final hasMilestones = goal.milestones.isNotEmpty;
    final hasRoutines = goal.linkedRoutineIds.isNotEmpty;
    final hasTodos = goal.linkedTodoIds.isNotEmpty;

    if (!hasMilestones && !hasRoutines && !hasTodos) return 0.0;

    double total = 0;
    double weight = 0;

    // 마일스톤 완료 비율
    if (hasMilestones) {
      final done = goal.milestones.where((m) => m.isCompleted).length;
      total += (done / goal.milestones.length) * 40;
      weight += 40;
    }

    // 연결된 루틴 최근 7일 완료율 평균
    if (hasRoutines) {
      double routineSum = 0;
      int count = 0;
      for (final rId in goal.linkedRoutineIds) {
        final rate = completionService.getCompletionRate(rId, 7);
        routineSum += rate;
        count++;
      }
      if (count > 0) {
        total += (routineSum / count) * 40;
      }
      weight += 40;
    }

    // 연결된 할일 완료 비율
    if (hasTodos) {
      final allTodos = todoService.getAll();
      int done = 0;
      int linkedCount = 0;
      for (final tId in goal.linkedTodoIds) {
        final todo = allTodos.where((t) => t.id == tId).firstOrNull;
        if (todo != null) {
          linkedCount++;
          if (todo.isCompleted) done++;
        }
      }
      if (linkedCount > 0) {
        total += (done / linkedCount) * 20;
      }
      weight += 20;
    }

    return weight > 0 ? (total / weight) : 0.0;
  }

  /// 전체 미완료 목표 평균 진행률
  double getOverallProgress(RoutineCompletionService completionService, TodoService todoService) {
    final incomplete = getIncomplete();
    if (incomplete.isEmpty) return 0.0;
    double sum = 0;
    for (final g in incomplete) {
      sum += getProgress(g, completionService, todoService);
    }
    return sum / incomplete.length;
  }
}
