import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/screen_time_data.dart';

class ScreenTimeService {
  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');
  static const _cacheKey = 'screen_time_cache';
  static const _cacheDateKey = 'screen_time_cache_date';
  static const _cacheTimeKey = 'screen_time_cache_time';

  final SharedPreferences _prefs;
  ScreenTimeData? _cached;

  ScreenTimeService(this._prefs) {
    _loadCache();
  }

  void _loadCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      _cached = ScreenTimeData.fromJson(jsonDecode(raw));
    } catch (_) {}
  }

  ScreenTimeData? getCached() {
    if (_cached == null) return null;
    final today = _todayStr();
    final cacheDate = _prefs.getString(_cacheDateKey) ?? '';
    if (cacheDate != today) return null;
    // Check 10-minute freshness
    final cacheTime = _prefs.getInt(_cacheTimeKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - cacheTime > 10 * 60 * 1000) return null;
    return _cached;
  }

  Future<ScreenTimeData?> fetchToday() async {
    // Return cache if fresh
    final cached = getCached();
    if (cached != null) return cached;

    final today = _todayStr();
    try {
      // Parallel native calls
      final results = await Future.wait([
        _channel.invokeMethod('queryDailyUsageStats', {'date': today}),
        _channel.invokeMethod('getUnlockCount', {'date': today}),
        _channel.invokeMethod('getHourlyUsage', {'date': today}),
      ]);

      final rawApps = (results[0] as List?) ?? [];
      final unlockCount = (results[1] as int?) ?? 0;
      final rawHourly = (results[2] as List?) ?? [];

      final apps = rawApps.map((e) {
        final m = Map<String, dynamic>.from(e);
        final pkg = m['appPackage'] as String? ?? '';
        return AppUsageInfo(
          appName: m['appLabel'] as String? ?? pkg,
          packageName: pkg,
          totalTimeMs: (m['totalTime'] as int?) ?? 0,
          category: AppUsageInfo.categorize(pkg),
        );
      }).where((a) => a.totalTimeMs > 0).toList();

      final totalTime = apps.fold<int>(0, (sum, a) => sum + a.totalTimeMs);
      final hourly = rawHourly.map((e) => (e as int?) ?? 0).toList();
      while (hourly.length < 24) hourly.add(0);

      final data = ScreenTimeData(
        date: today,
        totalTimeMs: totalTime,
        unlockCount: unlockCount,
        apps: apps,
        hourlyUsageMs: hourly.take(24).toList(),
      );

      // Cache
      _cached = data;
      _prefs.setString(_cacheKey, jsonEncode(data.toJson()));
      _prefs.setString(_cacheDateKey, today);
      _prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

      return data;
    } catch (e) {
      print('[ScreenTimeService] fetchToday error: $e');
      return _cached;
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
