import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weekly_report_data.dart';
import 'routine_service.dart';
import 'routine_completion_service.dart';
import 'distraction_log_service.dart';
import 'growth_service.dart';
import 'gemini_service.dart';

class WeeklyReportService {
  static const _cachePrefix = 'weekly_report_';

  final SharedPreferences _prefs;
  final RoutineService _routine;
  final RoutineCompletionService _completion;
  final DistractionLogService _distraction;
  final GrowthService _growth;
  final GeminiService _gemini;

  WeeklyReportService({
    required SharedPreferences prefs,
    required RoutineService routine,
    required RoutineCompletionService completion,
    required DistractionLogService distraction,
    required GrowthService growth,
    required GeminiService gemini,
  })  : _prefs = prefs,
        _routine = routine,
        _completion = completion,
        _distraction = distraction,
        _growth = growth,
        _gemini = gemini;

  /// 주간 리포트 생성 (weeksAgo=0: 이번 주, 1: 지난 주)
  Future<WeeklyReportData> generateReport({int weeksAgo = 0}) async {
    final now = DateTime.now();
    final monday = _getMonday(now).subtract(Duration(days: weeksAgo * 7));
    final sunday = monday.add(const Duration(days: 6));
    final weekKey = _formatDate(monday);

    // 캐시 확인 (이번 주가 아닌 경우만)
    if (weeksAgo > 0) {
      final cached = _loadCache(weekKey);
      if (cached != null) return cached;
    }

    final routines = _routine.getAll();
    final dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dailyRates = <String, double>{};
    int totalCompleted = 0;
    int totalPossible = 0;

    // 요일별 완료율
    for (int d = 0; d < 7; d++) {
      final date = monday.add(Duration(days: d));
      if (date.isAfter(now)) break;
      final dateStr = _formatDate(date);
      final activeRoutines = routines.where((r) => r.isActiveOnDate(date)).toList();
      if (activeRoutines.isEmpty) {
        dailyRates[dayKeys[d]] = 0;
        continue;
      }
      int dayCompleted = 0;
      for (final r in activeRoutines) {
        if (_completion.isCompleted(r.id, dateStr)) {
          dayCompleted++;
          totalCompleted++;
        }
        totalPossible++;
      }
      dailyRates[dayKeys[d]] = activeRoutines.isEmpty ? 0 : dayCompleted / activeRoutines.length;
    }

    final overallRate = totalPossible > 0 ? totalCompleted / totalPossible : 0.0;

    // 루틴별 통계
    final routineStats = <RoutineWeekStat>[];
    for (final r in routines) {
      int completed = 0;
      int total = 0;
      for (int d = 0; d < 7; d++) {
        final date = monday.add(Duration(days: d));
        if (date.isAfter(now)) break;
        if (!r.isActiveOnDate(date)) continue;
        total++;
        final dateStr = _formatDate(date);
        if (_completion.isCompleted(r.id, dateStr)) completed++;
      }
      if (total > 0) {
        routineStats.add(RoutineWeekStat(
          routineId: r.id,
          routineName: r.name,
          completedDays: completed,
          totalDays: total,
          rate: completed / total,
        ));
      }
    }
    routineStats.sort((a, b) => b.rate.compareTo(a.rate));

    // 딴짓 통계
    int totalDistractions = 0;
    Duration totalDistractionTime = Duration.zero;
    final appCounts = <String, int>{};
    for (int d = 0; d < 7; d++) {
      final date = monday.add(Duration(days: d));
      if (date.isAfter(now)) break;
      final dateStr = _formatDate(date);
      final logs = _distraction.getByDate(dateStr);
      totalDistractions += logs.length;
      for (final log in logs) {
        totalDistractionTime += log.duration;
        appCounts[log.appLabel] = (appCounts[log.appLabel] ?? 0) + 1;
      }
    }
    String? mostDistractedApp;
    if (appCounts.isNotEmpty) {
      mostDistractedApp = appCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // XP 계산
    final growth = _growth.currentData;
    int xpEarned = 0;
    for (int d = 0; d < 7; d++) {
      final date = monday.add(Duration(days: d));
      if (date.isAfter(now)) break;
      final dateStr = _formatDate(date);
      xpEarned += growth.xpHistory[dateStr] ?? 0;
    }

    // 주차 라벨
    final month = monday.month;
    final weekOfMonth = ((monday.day - 1) / 7).floor() + 1;
    final weekLabel = '$month월 $weekOfMonth주차';

    // 루나 코멘트
    String lunaComment = '';
    try {
      final prompt = '주간 리포트 코멘트 1-2문장 만들어줘.\n'
          '완료율: ${(overallRate * 100).round()}%, 딴짓: $totalDistractions번, XP: $xpEarned\n'
          '최고 루틴: ${routineStats.isNotEmpty ? routineStats.first.routineName : "없음"}\n'
          '규칙: 반말, 격려, 구체적 수치 언급';
      final result = await _gemini.generateRecommendation(prompt);
      lunaComment = result ?? '';
    } catch (_) {}

    final report = WeeklyReportData(
      weekLabel: weekLabel,
      overallCompletionRate: overallRate,
      dailyRates: dailyRates,
      totalCompletedCount: totalCompleted,
      totalDistractionCount: totalDistractions,
      totalDistractionTime: totalDistractionTime,
      mostDistractedApp: mostDistractedApp,
      xpEarned: xpEarned,
      lunaComment: lunaComment,
      routineStats: routineStats,
      startDate: _formatDate(monday),
      endDate: _formatDate(sunday),
    );

    // 캐시 저장
    await _prefs.setString('$_cachePrefix$weekKey', jsonEncode(report.toJson()));

    return report;
  }

  WeeklyReportData? _loadCache(String weekKey) {
    final raw = _prefs.getString('$_cachePrefix$weekKey');
    if (raw == null) return null;
    try {
      return WeeklyReportData.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  DateTime _getMonday(DateTime date) {
    final diff = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day - diff);
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
