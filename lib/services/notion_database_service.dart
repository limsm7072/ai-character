import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notion_database.dart';

class NotionDatabaseService {
  static const _key = 'notion_databases';
  final SharedPreferences _prefs;

  NotionDatabaseService(this._prefs);

  List<NotionDatabase> getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => NotionDatabase.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  NotionDatabase? getById(String id) {
    return getAll().where((d) => d.id == id).firstOrNull;
  }

  List<NotionDatabase> getRecent({int limit = 3}) {
    return getAll().take(limit).toList();
  }

  Future<NotionDatabase> add({String title = '새 데이터베이스', String? icon}) async {
    final dbs = getAll();
    final db = NotionDatabase(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      icon: icon,
      columns: [
        DatabaseColumn(
          id: '${DateTime.now().millisecondsSinceEpoch}_col0',
          name: '이름',
          type: ColumnType.text,
          order: 0,
        ),
      ],
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    dbs.insert(0, db);
    await _save(dbs);
    return db;
  }

  Future<void> update(NotionDatabase db) async {
    final dbs = getAll();
    final idx = dbs.indexWhere((d) => d.id == db.id);
    if (idx >= 0) {
      db.updatedAt = DateTime.now().millisecondsSinceEpoch;
      dbs[idx] = db;
      await _save(dbs);
    }
  }

  Future<void> delete(String id) async {
    final dbs = getAll();
    dbs.removeWhere((d) => d.id == id);
    await _save(dbs);
  }

  // Column operations
  Future<void> addColumn(String dbId, DatabaseColumn col) async {
    final db = getById(dbId);
    if (db == null) return;
    col.order = db.columns.length;
    db.columns.add(col);
    await update(db);
  }

  Future<void> updateColumn(String dbId, DatabaseColumn col) async {
    final db = getById(dbId);
    if (db == null) return;
    final idx = db.columns.indexWhere((c) => c.id == col.id);
    if (idx >= 0) {
      db.columns[idx] = col;
      await update(db);
    }
  }

  Future<void> removeColumn(String dbId, String colId) async {
    final db = getById(dbId);
    if (db == null) return;
    db.columns.removeWhere((c) => c.id == colId);
    for (final row in db.rows) {
      row.cells.remove(colId);
    }
    await update(db);
  }

  // Row operations
  Future<DatabaseRow> addRow(String dbId, {Map<String, dynamic>? cells}) async {
    final db = getById(dbId);
    final row = DatabaseRow(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cells: cells ?? {},
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    if (db != null) {
      db.rows.add(row);
      await update(db);
    }
    return row;
  }

  Future<void> updateRow(String dbId, DatabaseRow row) async {
    final db = getById(dbId);
    if (db == null) return;
    final idx = db.rows.indexWhere((r) => r.id == row.id);
    if (idx >= 0) {
      db.rows[idx] = row;
      await update(db);
    }
  }

  Future<void> removeRow(String dbId, String rowId) async {
    final db = getById(dbId);
    if (db == null) return;
    db.rows.removeWhere((r) => r.id == rowId);
    await update(db);
  }

  // Export / Import
  String exportAsJson(NotionDatabase db) {
    return const JsonEncoder.withIndent('  ').convert(db.toJson());
  }

  String exportAllAsJson() {
    final dbs = getAll();
    return const JsonEncoder.withIndent('  ')
        .convert(dbs.map((d) => d.toJson()).toList());
  }

  NotionDatabase? importFromJson(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr);
      if (data is Map<String, dynamic>) {
        final db = NotionDatabase.fromJson(data);
        db.id = DateTime.now().millisecondsSinceEpoch.toString();
        db.updatedAt = DateTime.now().millisecondsSinceEpoch;
        final dbs = getAll();
        dbs.insert(0, db);
        _save(dbs);
        return db;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(List<NotionDatabase> dbs) async {
    await _prefs.setString(
        _key, jsonEncode(dbs.map((d) => d.toJson()).toList()));
  }
}
