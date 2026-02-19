import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary.dart';

class DiaryService {
  static const _key = 'diaries';
  final SharedPreferences _prefs;

  DiaryService(this._prefs);

  List<Diary> getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Diary.fromJson(e)).toList();
  }

  Future<void> _saveAll(List<Diary> diaries) async {
    final json = jsonEncode(diaries.map((d) => d.toJson()).toList());
    await _prefs.setString(_key, json);
  }

  /// Get diary for a specific date (yyyy-MM-dd), or null if none exists.
  Diary? getByDate(String date) {
    final diaries = getAll();
    for (final d in diaries) {
      if (d.date == date) return d;
    }
    return null;
  }

  /// Create or update diary for a date.
  Future<Diary> save(Diary diary) async {
    final diaries = getAll();
    final index = diaries.indexWhere((d) => d.id == diary.id);
    diary.updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (index >= 0) {
      diaries[index] = diary;
    } else {
      diaries.add(diary);
    }
    await _saveAll(diaries);
    return diary;
  }

  Future<void> delete(String id) async {
    final diaries = getAll();
    diaries.removeWhere((d) => d.id == id);
    await _saveAll(diaries);
  }

  /// Get recent diaries sorted by date descending.
  List<Diary> getRecent({int limit = 5}) {
    final diaries = getAll();
    diaries.sort((a, b) => b.date.compareTo(a.date));
    return diaries.take(limit).toList();
  }

  /// Get diaries for a specific month (yyyy-MM).
  List<Diary> getByMonth(int year, int month) {
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    return getAll().where((d) => d.date.startsWith(prefix)).toList();
  }

  /// Check if there's a streak up to today, returns streak count.
  int getCurrentStreak() {
    final diaries = getAll();
    final dateSet = diaries.map((d) => d.date).toSet();
    int streak = 0;
    var date = DateTime.now();
    while (true) {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (dateSet.contains(dateStr)) {
        streak++;
        date = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}
