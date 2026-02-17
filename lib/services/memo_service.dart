import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memo.dart';

class MemoService {
  static const _key = 'memos';
  final SharedPreferences _prefs;

  MemoService(this._prefs);

  List<Memo> getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Memo.fromJson(e)).toList();
  }

  Future<void> _saveAll(List<Memo> memos) async {
    final json = jsonEncode(memos.map((m) => m.toJson()).toList());
    await _prefs.setString(_key, json);
  }

  Future<Memo> add(String title, {String content = ''}) async {
    final memos = getAll();
    final now = DateTime.now().millisecondsSinceEpoch;
    final memo = Memo(
      id: now.toString(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    memos.add(memo);
    await _saveAll(memos);
    return memo;
  }

  Future<void> update(Memo memo) async {
    final memos = getAll();
    final index = memos.indexWhere((m) => m.id == memo.id);
    if (index >= 0) {
      memo.updatedAt = DateTime.now().millisecondsSinceEpoch;
      memos[index] = memo;
      await _saveAll(memos);
    }
  }

  Future<void> delete(String id) async {
    final memos = getAll();
    memos.removeWhere((m) => m.id == id);
    await _saveAll(memos);
  }

  List<Memo> getRecent({int limit = 2}) {
    final memos = getAll();
    memos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return memos.take(limit).toList();
  }
}
