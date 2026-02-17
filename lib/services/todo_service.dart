import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';

class TodoService {
  static const _key = 'todos';
  final SharedPreferences _prefs;

  TodoService(this._prefs);

  List<Todo> getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Todo.fromJson(e)).toList();
  }

  Future<void> _saveAll(List<Todo> todos) async {
    final json = jsonEncode(todos.map((t) => t.toJson()).toList());
    await _prefs.setString(_key, json);
  }

  Future<Todo> add(String title) async {
    final todos = getAll();
    final todo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    todos.add(todo);
    await _saveAll(todos);
    return todo;
  }

  Future<void> update(Todo todo) async {
    final todos = getAll();
    final index = todos.indexWhere((t) => t.id == todo.id);
    if (index >= 0) {
      todos[index] = todo;
      await _saveAll(todos);
    }
  }

  Future<void> delete(String id) async {
    final todos = getAll();
    todos.removeWhere((t) => t.id == id);
    await _saveAll(todos);
  }

  Future<void> toggleComplete(String id) async {
    final todos = getAll();
    final index = todos.indexWhere((t) => t.id == id);
    if (index >= 0) {
      todos[index].isCompleted = !todos[index].isCompleted;
      todos[index].completedAt = todos[index].isCompleted
          ? DateTime.now().millisecondsSinceEpoch
          : null;
      await _saveAll(todos);
    }
  }

  List<Todo> getIncomplete() {
    return getAll().where((t) => !t.isCompleted).toList();
  }

  int get incompleteCount => getIncomplete().length;
}
