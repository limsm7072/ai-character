import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notion_page.dart';
import '../models/routine.dart';
import 'notion_page_service.dart';
import 'routine_service.dart';
import 'routine_completion_service.dart';
import 'todo_service.dart';
import 'diary_service.dart';
import 'calendar_service.dart';
import 'health_service.dart';
import 'screen_time_service.dart';
import 'activity_service.dart';
import 'weather_service.dart';
import 'goal_service.dart';
import 'gemini_service.dart';
import 'settings_service.dart';

class AutoPageService {
  final NotionPageService _pageService;
  final RoutineService _routineService;
  final RoutineCompletionService _completionService;
  final TodoService _todoService;
  final DiaryService _diaryService;
  final CalendarService _calendarService;
  final HealthService? _healthService;
  final ScreenTimeService _screenTimeService;
  final ActivityService _activityService;
  final WeatherService _weatherService;
  final GoalService _goalService;
  final GeminiService? _geminiService;
  final SettingsService _settingsService;
  final SharedPreferences _prefs;

  static const _lastDailyKey = 'auto_page_last_daily';
  static const _lastWeeklyKey = 'auto_page_last_weekly';

  AutoPageService({
    required NotionPageService pageService,
    required RoutineService routineService,
    required RoutineCompletionService completionService,
    required TodoService todoService,
    required DiaryService diaryService,
    required CalendarService calendarService,
    HealthService? healthService,
    required ScreenTimeService screenTimeService,
    required ActivityService activityService,
    required WeatherService weatherService,
    required GoalService goalService,
    GeminiService? geminiService,
    required SettingsService settingsService,
    required SharedPreferences prefs,
  })  : _pageService = pageService,
        _routineService = routineService,
        _completionService = completionService,
        _todoService = todoService,
        _diaryService = diaryService,
        _calendarService = calendarService,
        _healthService = healthService,
        _screenTimeService = screenTimeService,
        _activityService = activityService,
        _weatherService = weatherService,
        _goalService = goalService,
        _geminiService = geminiService,
        _settingsService = settingsService,
        _prefs = prefs;

  int _blockId = 0;
  String _newId() => '${DateTime.now().millisecondsSinceEpoch}_${_blockId++}';

  // ─── Daily Summary ───

  Future<NotionPage> generateDailySummary(String date) async {
    _blockId = 0;
    final dt = DateTime.tryParse(date) ?? DateTime.now();
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final dayName = weekdays[dt.weekday - 1];
    final title = '[루나] ${dt.month}월 ${dt.day}일 ($dayName) 오늘의 정리';

    // Check existing
    final existing = _findExisting(title);
    final blocks = <PageBlock>[];

    // Weather
    final weather = _weatherService.getCached();
    if (weather != null) {
      final desc = _weatherDescription(weather.weatherCode);
      blocks.add(PageBlock(
        id: _newId(), type: BlockType.callout,
        calloutIcon: _weatherIcon(weather.weatherCode),
        content: '${weather.temperature.round()}°C, $desc / 습도 ${weather.humidity}%',
      ));
      blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
    }

    // Routines
    final routines = _routineService.getAll()
        .where((r) => r.isEnabled && _isActiveOnDate(r, dt))
        .toList();
    final completions = _completionService.getCompletionsByDate(date);
    if (routines.isNotEmpty) {
      blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '루틴'));
      final completedIds = completions
          .where((c) => c.status == 'completed')
          .map((c) => c.routineId)
          .toSet();
      final tableData = <List<String>>[
        ['루틴', '시간', '상태'],
      ];
      for (final r in routines) {
        final time = r.isAllDay
            ? '하루종일'
            : '${r.startTime.hour.toString().padLeft(2, '0')}:${r.startTime.minute.toString().padLeft(2, '0')}';
        final status = completedIds.contains(r.id) ? '✅ 완료' : '⬜ 미완료';
        tableData.add([r.name, time, status]);
      }
      blocks.add(PageBlock(
        id: _newId(), type: BlockType.table, tableData: tableData,
      ));
      final done = completedIds.length;
      final total = routines.length;
      final rate = total > 0 ? (done / total * 100).round() : 0;
      blocks.add(PageBlock(
        id: _newId(), type: BlockType.text,
        content: '완료율: $done/$total ($rate%)',
      ));
      blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
    }

    // Todos
    final allTodos = _todoService.getAll();
    final todayStart = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
    final todayEnd = todayStart + 86400000;
    final completedToday = allTodos.where((t) =>
        t.isCompleted && t.completedAt != null &&
        t.completedAt! >= todayStart && t.completedAt! < todayEnd).toList();
    final incomplete = allTodos.where((t) => !t.isCompleted).toList();
    if (completedToday.isNotEmpty || incomplete.isNotEmpty) {
      blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '할 일'));
      for (final t in completedToday) {
        blocks.add(PageBlock(
          id: _newId(), type: BlockType.todo,
          content: t.title, isChecked: true,
        ));
      }
      for (final t in incomplete.take(10)) {
        blocks.add(PageBlock(
          id: _newId(), type: BlockType.todo,
          content: t.title, isChecked: false,
        ));
      }
      if (incomplete.length > 10) {
        blocks.add(PageBlock(
          id: _newId(), type: BlockType.text,
          content: '... 외 ${incomplete.length - 10}개',
        ));
      }
      blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
    }

    // Calendar
    final events = _calendarService.getByDate(date);
    if (events.isNotEmpty) {
      blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '일정'));
      for (final e in events) {
        final time = e.startHour != null
            ? '${e.startHour!.toString().padLeft(2, '0')}:${(e.startMinute ?? 0).toString().padLeft(2, '0')} '
            : '';
        blocks.add(PageBlock(
          id: _newId(), type: BlockType.bulletList,
          content: '$time${e.title}',
        ));
      }
      blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
    }

    // Health
    if (_healthService != null) {
      try {
        final steps = await _healthService!.getTodaySteps();
        final sleep = await _healthService!.getLastSleep();
        final hr = await _healthService!.getTodayHeartRateRange();
        if (steps > 0 || sleep != null || hr != null) {
          blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '건강'));
          final healthRows = <List<String>>[['항목', '수치']];
          if (steps > 0) healthRows.add(['걸음수', '$steps보']);
          if (sleep != null) {
            final hours = sleep.total.inHours;
            final mins = sleep.total.inMinutes % 60;
            healthRows.add(['수면', '${hours}시간 ${mins}분']);
          }
          if (hr != null) healthRows.add(['심박수', '${hr.avg} bpm']);
          blocks.add(PageBlock(
            id: _newId(), type: BlockType.table, tableData: healthRows,
          ));
          blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
        }
      } catch (_) {}
    }

    // Screen Time
    try {
      final screen = await _screenTimeService.fetchToday();
      if (screen != null && screen.totalTimeMs > 0) {
        blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '스크린 타임'));
        blocks.add(PageBlock(
          id: _newId(), type: BlockType.text,
          content: '총 ${screen.formattedTotalTime} / 잠금해제 ${screen.unlockCount}회',
        ));
        for (final app in screen.topApps.take(3)) {
          blocks.add(PageBlock(
            id: _newId(), type: BlockType.bulletList,
            content: '${app.appName} — ${_formatMs(app.totalTimeMs)}',
          ));
        }
        blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
      }
    } catch (_) {}

    // Activity
    try {
      final activity = await _activityService.fetchToday();
      if (activity != null && activity.entries.isNotEmpty) {
        final parts = <String>[];
        if (activity.walkingMinutes > 0) parts.add('걷기 ${activity.walkingMinutes}분');
        if (activity.runningMinutes > 0) parts.add('달리기 ${activity.runningMinutes}분');
        if (activity.cyclingMinutes > 0) parts.add('자전거 ${activity.cyclingMinutes}분');
        if (activity.vehicleMinutes > 0) parts.add('차량 ${activity.vehicleMinutes}분');
        if (parts.isNotEmpty) {
          blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '활동'));
          blocks.add(PageBlock(
            id: _newId(), type: BlockType.text,
            content: parts.join(' · '),
          ));
          blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
        }
      }
    } catch (_) {}

    // Diary
    final diary = _diaryService.getByDate(date);
    if (diary != null && diary.content.isNotEmpty) {
      blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '일기'));
      final moodEmojis = ['😢', '😟', '😐', '😊', '😄'];
      blocks.add(PageBlock(
        id: _newId(), type: BlockType.callout,
        calloutIcon: moodEmojis[diary.mood.clamp(0, 4)],
        content: diary.content,
      ));
      blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
    }

    // Luna comment
    final comment = await _generateComment(
      routines: routines.length,
      routineDone: completions.where((c) => c.status == 'completed').length,
      todoDone: completedToday.length,
      todoLeft: incomplete.length,
      mood: diary?.mood,
    );
    blocks.add(PageBlock(
      id: _newId(), type: BlockType.callout,
      calloutIcon: '🌙',
      content: comment,
    ));

    // Save or update
    final page = existing ?? await _pageService.add(title: title, icon: '📋');
    page.blocks = blocks;
    await _pageService.update(page);
    await _prefs.setString(_lastDailyKey, date);
    await cleanupOldPages();
    return page;
  }

  // ─── Planning Page ───

  Future<NotionPage> generatePlanningPage(String date) async {
    _blockId = 0;
    final dt = DateTime.tryParse(date) ?? DateTime.now().add(const Duration(days: 1));
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final dayName = weekdays[dt.weekday - 1];
    final title = '[루나] ${dt.month}월 ${dt.day}일 ($dayName) 계획';

    final existing = _findExisting(title);
    final blocks = <PageBlock>[];

    // Tomorrow weather
    final weather = _weatherService.getCached();
    if (weather != null && weather.daily.isNotEmpty) {
      // Find tomorrow's forecast
      final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final daily = weather.daily.where((d) => d.date == dateStr).firstOrNull;
      if (daily != null) {
        blocks.add(PageBlock(
          id: _newId(), type: BlockType.callout,
          calloutIcon: _weatherIcon(daily.weatherCode),
          content: '${daily.maxTemp.round()}°C / ${daily.minTemp.round()}°C, ${_weatherDescription(daily.weatherCode)}',
        ));
        blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
      }
    }

    // Calendar events
    final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final events = _calendarService.getByDate(dateStr);
    if (events.isNotEmpty) {
      blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '예정된 일정'));
      for (final e in events) {
        final time = e.startHour != null
            ? '${e.startHour!.toString().padLeft(2, '0')}:${(e.startMinute ?? 0).toString().padLeft(2, '0')} '
            : '';
        blocks.add(PageBlock(
          id: _newId(), type: BlockType.bulletList,
          content: '$time${e.title}',
        ));
      }
      blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
    }

    // Incomplete todos
    final incomplete = _todoService.getAll().where((t) => !t.isCompleted).toList();
    // Sort by due date
    incomplete.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
    if (incomplete.isNotEmpty) {
      blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '할 일'));
      for (final t in incomplete.take(15)) {
        final due = t.dueDate != null ? ' (${t.dueDate})' : '';
        blocks.add(PageBlock(
          id: _newId(), type: BlockType.todo,
          content: '${t.title}$due', isChecked: false,
        ));
      }
      blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
    }

    // Routines for that day
    final routines = _routineService.getAll()
        .where((r) => r.isEnabled && _isActiveOnDate(r, dt))
        .toList();
    if (routines.isNotEmpty) {
      blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '루틴'));
      for (final r in routines) {
        final time = r.isAllDay
            ? '하루종일'
            : '${r.startTime.hour.toString().padLeft(2, '0')}:${r.startTime.minute.toString().padLeft(2, '0')}~${r.endTime.hour.toString().padLeft(2, '0')}:${r.endTime.minute.toString().padLeft(2, '0')}';
        blocks.add(PageBlock(
          id: _newId(), type: BlockType.bulletList,
          content: '${r.name} ($time)',
        ));
      }
      blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
    }

    // Goals
    final goals = _goalService.getIncomplete();
    if (goals.isNotEmpty) {
      blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '목표 체크'));
      for (final g in goals.take(5)) {
        final progress = _goalService.getProgress(g, _completionService, _todoService);
        final pct = (progress * 100).round();
        final dday = g.dDayString;
        blocks.add(PageBlock(
          id: _newId(), type: BlockType.bulletList,
          content: '${g.title} ($pct%)${dday != null ? ' [$dday]' : ''}',
        ));
      }
      blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
    }

    // Luna comment
    final comment = await _generatePlanComment(
      eventCount: events.length,
      todoCount: incomplete.length,
      routineCount: routines.length,
    );
    blocks.add(PageBlock(
      id: _newId(), type: BlockType.callout,
      calloutIcon: '🌟',
      content: comment,
    ));

    final page = existing ?? await _pageService.add(title: title, icon: '📝');
    page.blocks = blocks;
    await _pageService.update(page);
    await cleanupOldPages();
    return page;
  }

  // ─── Weekly Review ───

  Future<NotionPage> generateWeeklyReview() async {
    _blockId = 0;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekNum = ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).ceil();
    final title = '[루나] ${now.month}월 ${weekNum}주차 주간 리뷰';

    final existing = _findExisting(title);
    final blocks = <PageBlock>[];

    // Routine completion by day
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final routineTable = <List<String>>[['요일', '완료', '전체', '완료율']];
    int weekRoutinesDone = 0, weekRoutinesTotal = 0;

    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      if (day.isAfter(now)) break;
      final dayStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final dayRoutines = _routineService.getAll()
          .where((r) => r.isEnabled && _isActiveOnDate(r, day))
          .length;
      final dayDone = _completionService.getCompletionsByDate(dayStr)
          .where((c) => c.status == 'completed')
          .length;
      final rate = dayRoutines > 0 ? (dayDone / dayRoutines * 100).round() : 0;
      routineTable.add([weekdays[i], '$dayDone', '$dayRoutines', '$rate%']);
      weekRoutinesDone += dayDone;
      weekRoutinesTotal += dayRoutines;
    }

    if (weekRoutinesTotal > 0) {
      blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '루틴 완료율'));
      blocks.add(PageBlock(
        id: _newId(), type: BlockType.table, tableData: routineTable,
      ));
      final weekRate = (weekRoutinesDone / weekRoutinesTotal * 100).round();
      blocks.add(PageBlock(
        id: _newId(), type: BlockType.text,
        content: '주간 평균: $weekRate%',
      ));
      blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
    }

    // Todo stats
    final allTodos = _todoService.getAll();
    final weekStartMs = DateTime(weekStart.year, weekStart.month, weekStart.day).millisecondsSinceEpoch;
    final weekEndMs = weekStartMs + 7 * 86400000;
    final completedThisWeek = allTodos.where((t) =>
        t.isCompleted && t.completedAt != null &&
        t.completedAt! >= weekStartMs && t.completedAt! < weekEndMs).length;
    final createdThisWeek = allTodos.where((t) =>
        t.createdAt >= weekStartMs && t.createdAt < weekEndMs).length;
    final remaining = allTodos.where((t) => !t.isCompleted).length;

    blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '할 일 현황'));
    blocks.add(PageBlock(
      id: _newId(), type: BlockType.text,
      content: '이번 주 완료 $completedThisWeek개 · 생성 $createdThisWeek개 · 남은 할일 $remaining개',
    ));
    blocks.add(PageBlock(id: _newId(), type: BlockType.divider));

    // Goals progress
    final goals = _goalService.getIncomplete();
    if (goals.isNotEmpty) {
      blocks.add(PageBlock(id: _newId(), type: BlockType.heading2, content: '목표 현황'));
      for (final g in goals.take(5)) {
        final progress = _goalService.getProgress(g, _completionService, _todoService);
        final pct = (progress * 100).round();
        blocks.add(PageBlock(
          id: _newId(), type: BlockType.bulletList,
          content: '${g.title} — $pct% (${g.category})',
        ));
      }
      blocks.add(PageBlock(id: _newId(), type: BlockType.divider));
    }

    // Luna weekly comment
    final comment = await _generateWeeklyComment(
      routineRate: weekRoutinesTotal > 0
          ? (weekRoutinesDone / weekRoutinesTotal * 100).round()
          : 0,
      todoCompleted: completedThisWeek,
      todoRemaining: remaining,
    );
    blocks.add(PageBlock(
      id: _newId(), type: BlockType.callout,
      calloutIcon: '📋',
      content: comment,
    ));

    final page = existing ?? await _pageService.add(title: title, icon: '📊');
    page.blocks = blocks;
    await _pageService.update(page);
    final weekStr = '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    await _prefs.setString(_lastWeeklyKey, weekStr);
    await cleanupOldPages();
    return page;
  }

  // ─── Cleanup ───

  Future<void> cleanupOldPages({int maxAutoPages = 14}) async {
    final allPages = _pageService.getAll();
    final autoPages = allPages
        .where((p) => p.isAutoGenerated && !p.isFavorite)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (autoPages.length > maxAutoPages) {
      for (final page in autoPages.skip(maxAutoPages)) {
        await _pageService.delete(page.id);
      }
    }
  }

  // ─── Helpers ───

  NotionPage? _findExisting(String title) {
    return _pageService.getAll().where((p) => p.title == title).firstOrNull;
  }

  bool _isActiveOnDate(Routine r, DateTime date) {
    if (r.startDate != null) {
      final start = DateTime.tryParse(r.startDate!);
      if (start != null && date.isBefore(DateTime(start.year, start.month, start.day))) {
        return false;
      }
    }
    final dayIndex = date.weekday - 1; // 0=Mon
    return r.activeDays[dayIndex];
  }

  String _formatMs(int ms) {
    final mins = ms ~/ 60000;
    if (mins < 60) return '${mins}분';
    return '${mins ~/ 60}시간 ${mins % 60}분';
  }

  String _weatherDescription(int code) {
    if (code == 0) return '맑음';
    if (code <= 3) return '구름 조금';
    if (code <= 48) return '흐림';
    if (code <= 57) return '이슬비';
    if (code <= 67) return '비';
    if (code <= 77) return '눈';
    if (code <= 82) return '소나기';
    if (code <= 86) return '폭설';
    if (code <= 99) return '천둥번개';
    return '알 수 없음';
  }

  String _weatherIcon(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 48) return '☁️';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 86) return '🌨️';
    return '⛈️';
  }

  // ─── AI Comments ───

  Future<String> _generateComment({
    required int routines,
    required int routineDone,
    required int todoDone,
    required int todoLeft,
    int? mood,
  }) async {
    if (_geminiService == null) return _fallbackDailyComment(routineDone, routines);
    try {
      final moodStr = mood != null
          ? ['매우 나쁨', '나쁨', '보통', '좋음', '매우 좋음'][mood.clamp(0, 4)]
          : '모름';
      final prompt = '사용자 하루 요약이야. 반말로 1~2문장만 코멘트해줘:\n'
          '루틴 $routineDone/$routines 완료, 할일 $todoDone개 완료 $todoLeft개 남음, 기분: $moodStr';
      final result = await _geminiService!.generateRecommendation(prompt);
      if (result != null && result.trim().isNotEmpty) return result.trim();
    } catch (_) {}
    return _fallbackDailyComment(routineDone, routines);
  }

  String _fallbackDailyComment(int done, int total) {
    if (total == 0) return '오늘 하루도 수고했어! 내일도 화이팅 💪';
    final rate = done / total;
    if (rate >= 0.8) return '오늘 정말 잘했어! 루틴 거의 다 지켰네 👏';
    if (rate >= 0.5) return '절반 이상 했으니 괜찮아! 내일은 더 해보자 💪';
    return '오늘은 좀 힘들었나봐... 내일은 다시 힘내자! 🍀';
  }

  Future<String> _generatePlanComment({
    required int eventCount,
    required int todoCount,
    required int routineCount,
  }) async {
    if (_geminiService == null) return '내일도 파이팅! 계획대로 하나씩 해보자 🌟';
    try {
      final prompt = '내일 계획 요약이야. 반말로 1~2문장 응원해줘:\n'
          '일정 ${eventCount}개, 할일 ${todoCount}개, 루틴 ${routineCount}개';
      final result = await _geminiService!.generateRecommendation(prompt);
      if (result != null && result.trim().isNotEmpty) return result.trim();
    } catch (_) {}
    return '내일도 파이팅! 계획대로 하나씩 해보자 🌟';
  }

  Future<String> _generateWeeklyComment({
    required int routineRate,
    required int todoCompleted,
    required int todoRemaining,
  }) async {
    if (_geminiService == null) return '이번 주도 수고했어! 다음 주도 화이팅 📋';
    try {
      final prompt = '주간 리뷰야. 반말로 1~2문장 코멘트해줘:\n'
          '루틴 완료율 $routineRate%, 할일 $todoCompleted개 완료, $todoRemaining개 남음';
      final result = await _geminiService!.generateRecommendation(prompt);
      if (result != null && result.trim().isNotEmpty) return result.trim();
    } catch (_) {}
    return '이번 주도 수고했어! 다음 주도 화이팅 📋';
  }
}
