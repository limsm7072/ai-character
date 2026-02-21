import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_data.dart';

class ActivityService {
  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');
  static const _enabledKey = 'activity_recognition_enabled';
  static const _cacheKey = 'activity_cache';
  static const _cacheDateKey = 'activity_cache_date';

  final SharedPreferences _prefs;
  ActivitySummary? _cached;

  ActivityService(this._prefs) {
    _loadCache();
  }

  void _loadCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      _cached = ActivitySummary.fromJson(jsonDecode(raw));
    } catch (_) {}
  }

  bool get isEnabled => _prefs.getBool(_enabledKey) ?? false;

  Future<bool> start() async {
    try {
      final ok = await _channel.invokeMethod('startActivityRecognition');
      if (ok == true) {
        await _prefs.setBool(_enabledKey, true);
        return true;
      }
      return false;
    } catch (e) {
      print('[ActivityService] start error: $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopActivityRecognition');
    } catch (_) {}
    await _prefs.setBool(_enabledKey, false);
  }

  ActivitySummary? getCached() {
    if (_cached == null) return null;
    final today = _todayStr();
    final cacheDate = _prefs.getString(_cacheDateKey) ?? '';
    if (cacheDate != today) return null;
    return _cached;
  }

  Future<ActivitySummary?> fetchToday() async {
    final today = _todayStr();
    try {
      final rawEntries = await _channel.invokeMethod('getActivityLog', {'date': today});
      final list = (rawEntries as List?) ?? [];

      final entries = list.map((e) {
        final m = Map<String, dynamic>.from(e);
        return ActivityEntry(
          type: _parseType(m['type'] as String? ?? ''),
          transition: m['transition'] as String? ?? '',
          timestamp: (m['timestamp'] as int?) ?? 0,
        );
      }).toList();

      final summary = ActivitySummary(date: today, entries: entries);
      _cached = summary;
      _prefs.setString(_cacheKey, jsonEncode(summary.toJson()));
      _prefs.setString(_cacheDateKey, today);
      return summary;
    } catch (e) {
      print('[ActivityService] fetchToday error: $e');
      return _cached;
    }
  }

  ActivityType _parseType(String s) {
    switch (s) {
      case 'walking': return ActivityType.walking;
      case 'running': return ActivityType.running;
      case 'cycling': return ActivityType.cycling;
      case 'vehicle': return ActivityType.vehicle;
      case 'still': return ActivityType.still;
      default: return ActivityType.unknown;
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
