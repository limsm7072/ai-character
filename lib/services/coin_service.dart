import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CoinService {
  static const _balanceKey = 'coin_balance';
  static const _todayDateKey = 'coin_today_date';
  static const _todayEarnedKey = 'coin_today_earned';
  static const _todayRoutinesKey = 'coin_today_routines';

  final SharedPreferences _prefs;

  static const _initKey = 'coin_initialized';

  CoinService(this._prefs) {
    // 첫 실행 시 웰컴 보너스 1000코인
    if (!(_prefs.getBool(_initKey) ?? false)) {
      _prefs.setBool(_initKey, true);
      _prefs.setInt(_balanceKey, 1000000);
    }
  }

  int get balance => _prefs.getInt(_balanceKey) ?? 0;

  String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int get todayEarned {
    if (_prefs.getString(_todayDateKey) != _todayStr) return 0;
    return _prefs.getInt(_todayEarnedKey) ?? 0;
  }

  Future<int> addCoins(int amount, String source) async {
    final newBalance = balance + amount;
    await _prefs.setInt(_balanceKey, newBalance);

    // Track today
    final today = _todayStr;
    if (_prefs.getString(_todayDateKey) != today) {
      await _prefs.setString(_todayDateKey, today);
      await _prefs.setInt(_todayEarnedKey, 0);
      await _prefs.setStringList(_todayRoutinesKey, []);
    }
    await _prefs.setInt(_todayEarnedKey, todayEarned + amount);

    return newBalance;
  }

  Future<bool> spendCoins(int amount, String source) async {
    if (balance < amount) return false;
    await _prefs.setInt(_balanceKey, balance - amount);
    return true;
  }

  /// Called when a routine is completed. Awards +5 coins.
  Future<void> onRoutineCompleted(String routineId) async {
    await addCoins(5, 'routine:$routineId');
  }

  /// Called when all daily routines are complete. Awards +20 coins.
  Future<void> onAllRoutinesComplete() async {
    await addCoins(20, 'all_complete');
  }

  /// Called on streak bonus. Awards streak * 2, max 30.
  Future<void> onStreakBonus(int streak) async {
    final bonus = (streak * 2).clamp(0, 30);
    if (bonus > 0) await addCoins(bonus, 'streak:$streak');
  }

  /// Called on level up. Awards +50 coins.
  Future<void> onLevelUp() async {
    await addCoins(50, 'level_up');
  }
}
