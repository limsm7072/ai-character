import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/briefing_data.dart';
import 'weather_service.dart';
import 'calendar_service.dart';
import 'todo_service.dart';
import 'routine_service.dart';
import 'routine_completion_service.dart';
import 'growth_service.dart';
import 'settings_service.dart';
import 'gemini_service.dart';

class BriefingService {
  static const _cacheKey = 'briefing_cache';
  static const _cacheDateKey = 'briefing_date';

  final SharedPreferences _prefs;
  final WeatherService _weather;
  final CalendarService _calendar;
  final TodoService _todo;
  final RoutineService _routine;
  final RoutineCompletionService _completion;
  final GrowthService _growth;
  final SettingsService _settings;
  final GeminiService _gemini;

  BriefingData? _cached;

  BriefingService({
    required SharedPreferences prefs,
    required WeatherService weather,
    required CalendarService calendar,
    required TodoService todo,
    required RoutineService routine,
    required RoutineCompletionService completion,
    required GrowthService growth,
    required SettingsService settings,
    required GeminiService gemini,
  })  : _prefs = prefs,
        _weather = weather,
        _calendar = calendar,
        _todo = todo,
        _routine = routine,
        _completion = completion,
        _growth = growth,
        _settings = settings,
        _gemini = gemini {
    _loadCache();
  }

  bool get hasTodayBriefing {
    final cached = _prefs.getString(_cacheDateKey);
    return cached == _today();
  }

  BriefingData? get cachedBriefing => _cached;

  Future<BriefingData> generateBriefing() async {
    // 캐시 확인
    if (_cached != null && _cached!.date == _today()) return _cached!;

    final todayStr = _today();
    final now = DateTime.now();

    // 날씨
    BriefingWeather? weather;
    try {
      final w = _weather.getCached() ??
          await _weather.fetch(_settings.weatherLat, _settings.weatherLon);
      if (w != null) {
        weather = BriefingWeather(
          temperature: w.temperature,
          weatherCode: w.weatherCode,
          high: w.daily.isNotEmpty ? w.daily.first.maxTemp : null,
          low: w.daily.isNotEmpty ? w.daily.first.minTemp : null,
          description: w.description,
        );
      }
    } catch (_) {}

    // 오늘 일정
    final events = _calendar.getByDate(todayStr);
    final briefingEvents = events.take(3).map((e) {
      String? timeStr;
      if (e.startHour != null) {
        timeStr = '${e.startHour.toString().padLeft(2, '0')}:${(e.startMinute ?? 0).toString().padLeft(2, '0')}';
      }
      return BriefingEvent(title: e.title, time: timeStr);
    }).toList();

    // 할일
    final pendingTodos = _todo.getIncomplete().length;

    // 오늘 루틴
    final allRoutines = _routine.getAll();
    final todayRoutines = allRoutines.where((r) => r.isActiveOnDate(now)).toList();
    final completedCount = todayRoutines.where((r) =>
        _completion.isCompleted(r.id, todayStr)).length;

    // 성장 데이터
    final growth = _growth.currentData;

    // Gemini 인사말 + 코멘트 생성
    String greeting = '좋은 아침이야!';
    String? lunaComment;

    try {
      final hour = now.hour;
      final timeOfDay = hour < 12 ? '아침' : hour < 18 ? '오후' : '저녁';
      final weatherInfo = weather != null ? '날씨: ${weather.description} ${weather.temperature.round()}°C' : '';
      final eventInfo = briefingEvents.isNotEmpty
          ? '일정: ${briefingEvents.map((e) => e.title).join(", ")}'
          : '일정 없음';
      final todoInfo = pendingTodos > 0 ? '할 일 ${pendingTodos}개' : '할 일 없음';
      final routineInfo = '루틴 ${todayRoutines.length}개 (완료 $completedCount개)';
      final growthInfo = 'Lv.${growth.level} ${growth.title}, 연속 ${growth.streak}일';

      final prompt = '지금 $timeOfDay이야. 짧은 인사말(1문장)과 오늘 브리핑 코멘트(1-2문장)를 만들어줘.\n'
          '정보: $weatherInfo, $eventInfo, $todoInfo, $routineInfo, $growthInfo\n'
          '형식: {"greeting":"인사말","comment":"코멘트"}\n'
          '규칙: 반말, 자연스럽게, 날씨/일정 정보를 활용해서 실용적인 한마디';

      final result = await _gemini.generateRecommendation(prompt);
      if (result != null) {
        try {
          final json = jsonDecode(result);
          greeting = json['greeting'] as String? ?? greeting;
          lunaComment = json['comment'] as String?;
        } catch (_) {
          // JSON 파싱 실패 시 결과를 그대로 사용
          greeting = result.length > 50 ? result.substring(0, 50) : result;
        }
      }
    } catch (_) {}

    final briefing = BriefingData(
      greeting: greeting,
      weather: weather,
      todayEvents: briefingEvents,
      pendingTodoCount: pendingTodos,
      todayRoutineCount: todayRoutines.length,
      completedRoutineCount: completedCount,
      lunaComment: lunaComment,
      date: todayStr,
    );

    // 캐시 저장
    _cached = briefing;
    await _prefs.setString(_cacheKey, jsonEncode(briefing.toJson()));
    await _prefs.setString(_cacheDateKey, todayStr);

    return briefing;
  }

  void _loadCache() {
    final dateStr = _prefs.getString(_cacheDateKey);
    if (dateStr != _today()) return;
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      _cached = BriefingData.fromJson(jsonDecode(raw));
    } catch (_) {}
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
