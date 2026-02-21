import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/growth_data.dart';

class GrowthService {
  static const _totalXpKey = 'growth_total_xp';
  static const _streakKey = 'growth_streak';
  static const _lastDateKey = 'growth_last_date';
  static const _todayXpKey = 'growth_today_xp';
  static const _todayDateKey = 'growth_today_date';
  static const _xpHistoryKey = 'growth_xp_history';

  final SharedPreferences _prefs;
  bool _didLevelUp = false;
  int _previousLevel = 1;

  GrowthService(this._prefs);

  /// 마지막 addXp 호출 시 레벨업이 발생했는지
  bool get didLevelUp => _didLevelUp;

  /// 레벨업 전 레벨
  int get previousLevel => _previousLevel;

  /// 현재 성장 데이터
  GrowthData get currentData {
    final todayStr = _today();
    final savedDate = _prefs.getString(_todayDateKey) ?? '';
    final todayXp = savedDate == todayStr ? (_prefs.getInt(_todayXpKey) ?? 0) : 0;

    return GrowthData(
      totalXp: _prefs.getInt(_totalXpKey) ?? 0,
      todayXp: todayXp,
      streak: _prefs.getInt(_streakKey) ?? 0,
      xpHistory: _loadHistory(),
    );
  }

  /// XP 추가. 레벨업 감지. 추가된 후의 총 XP 반환.
  Future<int> addXp(int amount, String source) async {
    if (amount <= 0) return currentData.totalXp;

    final data = currentData;
    _previousLevel = data.level;

    final newTotal = data.totalXp + amount;
    await _prefs.setInt(_totalXpKey, newTotal);

    // 오늘 XP 갱신
    final todayStr = _today();
    final savedDate = _prefs.getString(_todayDateKey) ?? '';
    int newTodayXp;
    if (savedDate == todayStr) {
      newTodayXp = (_prefs.getInt(_todayXpKey) ?? 0) + amount;
    } else {
      newTodayXp = amount;
      await _prefs.setString(_todayDateKey, todayStr);
    }
    await _prefs.setInt(_todayXpKey, newTodayXp);

    // 히스토리 갱신
    final history = _loadHistory();
    history[todayStr] = (history[todayStr] ?? 0) + amount;
    // 30일 초과 데이터 제거
    if (history.length > 30) {
      final sorted = history.keys.toList()..sort();
      while (history.length > 30) {
        history.remove(sorted.removeAt(0));
      }
    }
    await _prefs.setString(_xpHistoryKey, jsonEncode(history));

    // 레벨업 감지
    final newData = GrowthData(totalXp: newTotal);
    _didLevelUp = newData.level > _previousLevel;

    return newTotal;
  }

  /// 루틴 완료 시 XP 지급 (하루 한 번 루틴당)
  Future<void> onRoutineCompleted(String routineId) async {
    await addXp(10, 'routine:$routineId');
  }

  /// 연속 달성 업데이트 (하루 끝에 호출)
  Future<void> updateStreak(bool allCompleted) async {
    final todayStr = _today();
    final lastDate = _prefs.getString(_lastDateKey) ?? '';

    if (lastDate == todayStr) return; // 오늘 이미 처리됨

    int streak = _prefs.getInt(_streakKey) ?? 0;

    if (allCompleted) {
      // 어제 날짜인지 확인
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = _formatDate(yesterday);
      if (lastDate == yesterdayStr || lastDate.isEmpty) {
        streak++;
      } else {
        streak = 1; // 연속 끊김 → 1부터 다시 시작
      }

      // 연속 달성 보너스 XP
      final bonus = (streak * 2).clamp(0, 20);
      await addXp(bonus, 'streak:$streak');

      // 전체 완료 보너스
      await addXp(30, 'all_complete');
    } else {
      streak = 0;
    }

    await _prefs.setInt(_streakKey, streak);
    await _prefs.setString(_lastDateKey, todayStr);
  }

  Map<String, int> _loadHistory() {
    final raw = _prefs.getString(_xpHistoryKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k.toString(), v as int),
      );
    } catch (_) {
      return {};
    }
  }

  String _today() => _formatDate(DateTime.now());

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
