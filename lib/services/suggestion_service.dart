import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/routine_suggestion.dart';
import 'routine_service.dart';
import 'routine_completion_service.dart';
import 'distraction_log_service.dart';
import 'growth_service.dart';

class SuggestionService {
  static const _cacheKey = 'suggestion_cache';
  static const _cacheDateKey = 'suggestion_date';
  static const _cacheHours = 12;

  final SharedPreferences _prefs;
  final RoutineService _routine;
  final RoutineCompletionService _completion;
  final DistractionLogService _distraction;
  final GrowthService _growth;

  List<RoutineSuggestion>? _cached;

  SuggestionService({
    required SharedPreferences prefs,
    required RoutineService routine,
    required RoutineCompletionService completion,
    required DistractionLogService distraction,
    required GrowthService growth,
  })  : _prefs = prefs,
        _routine = routine,
        _completion = completion,
        _distraction = distraction,
        _growth = growth {
    _loadCache();
  }

  List<RoutineSuggestion>? get cachedSuggestions => _cached;

  List<RoutineSuggestion> generateSuggestions() {
    // 캐시 확인
    if (_cached != null && _isCacheValid()) return _cached!;

    final suggestions = <RoutineSuggestion>[];
    final routines = _routine.getAll();
    final now = DateTime.now();

    for (final r in routines) {
      // 완료율 분석 (최근 14일)
      final rate = _completion.getCompletionRate(r.id, 14);

      // 연속 달성 중인 루틴 칭찬
      if (rate >= 0.8) {
        final consecutiveDays = _getConsecutiveDays(r.id);
        if (consecutiveDays >= 3) {
          suggestions.add(RoutineSuggestion(
            type: SuggestionType.streak,
            title: '${r.name} ${consecutiveDays}일 연속 달성!',
            description: '꾸준히 잘하고 있어! 이 페이스 유지하자.',
            routineId: r.id,
            createdAt: now,
          ));
        }
      }

      // 완료율 낮은 루틴 개선 제안
      if (rate < 0.4 && rate > 0) {
        suggestions.add(RoutineSuggestion(
          type: SuggestionType.timeAdjust,
          title: '${r.name}, 시간대를 바꿔볼까?',
          description: '최근 완료율이 ${(rate * 100).round()}%야. 시간대나 요일을 조정하면 더 잘할 수 있을지도!',
          routineId: r.id,
          createdAt: now,
        ));
      }

      // 딴짓 많은 루틴 경고
      final stats = _distraction.getRoutineStats(r.id);
      if (stats.totalDistractions > 5) {
        final topApp = stats.appBreakdown.values
            .fold<MapEntry<String, int>?>(null, (prev, info) {
              final entry = MapEntry(info.appLabel, info.count);
              return prev == null || entry.value > prev.value ? entry : prev;
            });
        if (topApp != null) {
          suggestions.add(RoutineSuggestion(
            type: SuggestionType.warning,
            title: '${r.name} 중 ${topApp.key} 사용이 잦아요',
            description: '최근 ${stats.totalDistractions}번 딴짓이 감지됐어. 집중 모드를 활용해보는 건 어때?',
            routineId: r.id,
            createdAt: now,
          ));
        }
      }
    }

    // 성장 관련 제안
    final growth = _growth.currentData;
    if (growth.streak >= 7) {
      suggestions.add(RoutineSuggestion(
        type: SuggestionType.streak,
        title: '${growth.streak}일 연속 달성 중!',
        description: '대단해! Lv.${growth.level} ${growth.title}로서 멋진 기록이야.',
        createdAt: now,
      ));
    }

    // 루틴 없는 경우
    if (routines.isEmpty) {
      suggestions.add(RoutineSuggestion(
        type: SuggestionType.newHabit,
        title: '첫 루틴을 만들어볼까?',
        description: '작은 습관부터 시작해보자! 물 마시기, 스트레칭 같은 간단한 것부터.',
        createdAt: now,
      ));
    }

    // 최대 5개로 제한 (streak 우선, 그 다음 warning, 나머지)
    suggestions.sort((a, b) {
      const priority = {
        SuggestionType.streak: 0,
        SuggestionType.warning: 1,
        SuggestionType.timeAdjust: 2,
        SuggestionType.improvement: 3,
        SuggestionType.newHabit: 4,
      };
      return (priority[a.type] ?? 3).compareTo(priority[b.type] ?? 3);
    });
    final result = suggestions.take(5).toList();

    // 캐시 저장
    _cached = result;
    _saveCache(result);

    return result;
  }

  int _getConsecutiveDays(String routineId) {
    int count = 0;
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (_completion.isCompleted(routineId, dateStr)) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  bool _isCacheValid() {
    final dateStr = _prefs.getString(_cacheDateKey);
    if (dateStr == null) return false;
    final cached = DateTime.tryParse(dateStr);
    if (cached == null) return false;
    return DateTime.now().difference(cached).inHours < _cacheHours;
  }

  void _loadCache() {
    if (!_isCacheValid()) return;
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List);
      _cached = list.map((e) => RoutineSuggestion.fromJson(e)).toList();
    } catch (_) {}
  }

  Future<void> _saveCache(List<RoutineSuggestion> suggestions) async {
    await _prefs.setString(_cacheKey, jsonEncode(suggestions.map((s) => s.toJson()).toList()));
    await _prefs.setString(_cacheDateKey, DateTime.now().toIso8601String());
  }
}
