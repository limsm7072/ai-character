import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/routine_service.dart';
import '../services/routine_completion_service.dart';
import '../services/settings_service.dart';
import '../services/todo_service.dart';
import '../services/memo_service.dart';
import '../services/health_service.dart';
import '../services/distraction_log_service.dart';
import '../services/app_detection_service.dart';
import '../services/alarm_service.dart';
import '../services/timer_service.dart';
import '../services/calendar_service.dart';
import '../services/news_service.dart';
import '../services/card_service.dart';
import '../services/weather_service.dart';
import '../services/recommendation_service.dart';
import '../services/routine_group_service.dart';
import '../services/diary_service.dart';
import '../services/bookmark_service.dart';
import '../services/fortune_service.dart';
import '../services/goal_service.dart';
import '../models/fortune_data.dart';
import '../models/goal.dart';
import '../models/weather_data.dart';
import '../models/recommendation_data.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/news_ticker.dart';
import 'routine_list_screen.dart';
import 'todo_screen.dart';
import 'memo_list_screen.dart';
import 'stats_screen.dart';
import 'alarm_screen.dart';
import 'timer_screen.dart';
import 'calendar_screen.dart';
import 'card_screen.dart';
import 'weather_screen.dart';
import 'news_screen.dart';
import 'recommendation_screen.dart';
import 'diary_screen.dart';
import 'nature_scene_screen.dart';
import 'bookmark_screen.dart';
import 'fortune_screen.dart';
import 'goal_screen.dart';
import '../theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  final RoutineService routineService;
  final RoutineCompletionService completionService;
  final SettingsService settingsService;
  final TodoService todoService;
  final MemoService memoService;
  final HealthService? healthService;
  final DistractionLogService distractionLogService;
  final AppDetectionService? appDetection;
  final AlarmService alarmService;
  final TimerService timerService;
  final CalendarService calendarService;
  final NewsService newsService;
  final CardService cardService;
  final WeatherService weatherService;
  final RecommendationService recommendationService;
  final RoutineGroupService routineGroupService;
  final DiaryService diaryService;
  final BookmarkService bookmarkService;
  final FortuneService fortuneService;
  final GoalService goalService;
  final VoidCallback? onCompletionUnchecked;

  const DashboardScreen({
    super.key,
    required this.routineService,
    required this.completionService,
    required this.settingsService,
    required this.todoService,
    required this.memoService,
    required this.distractionLogService,
    this.healthService,
    this.appDetection,
    required this.alarmService,
    required this.timerService,
    required this.calendarService,
    required this.newsService,
    required this.cardService,
    required this.weatherService,
    required this.recommendationService,
    required this.routineGroupService,
    required this.diaryService,
    required this.bookmarkService,
    required this.fortuneService,
    required this.goalService,
    this.onCompletionUnchecked,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  List<String> _headlines = [];
  WeatherData? _weather;
  RecommendationData? _recommendation;
  FortuneData? _fortune;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _headlines = widget.newsService.getCached();
    _weather = widget.weatherService.getCached();
    _recommendation = widget.recommendationService.getCached();
    _fortune = widget.fortuneService.getCached() ?? widget.fortuneService.generateTodayFortune();
    _loadNews();
    _loadWeather();
    _loadRecommendation();
  }

  Future<void> _loadNews() async {
    final list = await widget.newsService.fetchHeadlines();
    if (mounted && list.isNotEmpty) setState(() => _headlines = list);
  }

  Future<void> _loadWeather() async {
    final lat = widget.settingsService.weatherLat;
    final lon = widget.settingsService.weatherLon;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 5)),
        );
        await widget.settingsService.setWeatherLocation(pos.latitude, pos.longitude);
        final data = await widget.weatherService.fetch(pos.latitude, pos.longitude);
        if (data != null && data.locationName.isNotEmpty) {
          await widget.settingsService.setWeatherLocationName(data.locationName);
        }
        if (mounted && data != null) setState(() => _weather = data);
        return;
      }
    } catch (_) {}
    final data = await widget.weatherService.fetch(lat, lon);
    if (data != null && data.locationName.isNotEmpty) {
      await widget.settingsService.setWeatherLocationName(data.locationName);
    }
    if (mounted && data != null) setState(() => _weather = data);
  }

  Future<void> _loadRecommendation() async {
    try {
      final data = await widget.recommendationService.fetch();
      if (mounted) setState(() => _recommendation = data);
    } catch (_) {}
  }

  void refresh() {
    _fortune = widget.fortuneService.generateTodayFortune();
    if (mounted) setState(() {});
    _loadNews();
    _loadWeather();
    _loadRecommendation();
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  // 섹션 빌더는 외부 Padding 없이 반환 → 레이아웃에서 패딩 적용
  Widget? _buildSection(String id, BuildContext context, DateTime now, String todayStr, ThemeData theme) {
    final large = widget.settingsService.isDashboardSectionLarge(id);
    final baseId = SettingsService.sectionBaseId(id);
    final label = _sectionLabel(id);
    switch (baseId) {
      case 'recommend':
        return large ? _buildRecommendLarge(theme, label) : _buildRecommendSmall(theme, label);
      case 'news':
        return large ? _buildNewsLarge(theme, label) : _buildNewsSmall(theme, label);
      case 'weather':
        return large ? _buildWeatherLarge(theme, label) : _buildWeatherSmall(theme, label);
      case 'routine':
        // Check if this section is linked to a work type
        final sectionWtId = widget.settingsService.getSectionWorkType(id);
        if (sectionWtId != null) {
          // Only show if today's work type matches
          final todayWtId = widget.calendarService.getDateWorkType(todayStr);
          if (todayWtId != sectionWtId) return null;
        }
        return large ? _buildRoutineLarge(context, now, todayStr, label) : _buildRoutineSmall(context, now, todayStr, label);
      case 'todo':
        return large ? _buildTodoLarge(context, label) : _buildTodoSmall(context, label);
      case 'card':
        return large ? _buildCardLarge(context, label) : _buildCardSmall(context, label);
      case 'calendar':
        return large ? _buildCalendarLarge(context, now, todayStr, label) : _buildCalendarSmall(context, now, todayStr, label);
      case 'stats':
        return large ? _buildStatsLarge(context, now, label) : _buildStatsSmall(context, now, label);
      case 'alarm':
        return large ? _buildAlarmLarge(context, label) : _buildAlarmSmall(context, label);
      case 'timer':
        return large ? _buildTimerLarge(context, label) : _buildTimerSmall(context, label);
      case 'diary':
        return large ? _buildDiaryLarge(context, label) : _buildDiarySmall(context, label);
      case 'memo':
        return large ? _buildMemoLarge(context, label) : _buildMemoSmall(context, label);
      case 'dday':
        return large ? _buildDDayLarge(context, now, label) : _buildDDaySmall(context, now, label);
      case 'nature':
        return large ? _buildNatureLarge(context, label) : _buildNatureSmall(context, label);
      case 'bookmark':
        return large ? _buildBookmarkLarge(context, label) : _buildBookmarkSmall(context, label);
      case 'fortune':
        return large ? _buildFortuneLarge(context, theme, label) : _buildFortuneSmall(context, theme, label);
      case 'goal':
        return large ? _buildGoalLarge(context, theme, label) : _buildGoalSmall(context, theme, label);
      default:
        return null;
    }
  }

  // ─── 맞춤 정보 ──────────────────────────────────────

  Widget? _buildRecommendLarge(ThemeData theme, String label) {
    final tipCount = _recommendation?.tips.length ?? 0;
    final articleCount = _recommendation?.articles.length ?? 0;
    if (tipCount == 0 && articleCount == 0 && _recommendation == null) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, RecommendationScreen(recommendationService: widget.recommendationService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (tipCount + articleCount > 0)
                  Text('${tipCount + articleCount}건', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            if (_recommendation != null && _recommendation!.tips.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._recommendation!.tips.take(2).map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.5), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tip.title, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              )),
            ],
            if (_recommendation != null && _recommendation!.articles.isNotEmpty) ...[
              const SizedBox(height: 4),
              ..._recommendation!.articles.take(2).map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.article_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a.title, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildRecommendSmall(ThemeData theme, String label) {
    final tipCount = _recommendation?.tips.length ?? 0;
    final articleCount = _recommendation?.articles.length ?? 0;
    if (tipCount == 0 && articleCount == 0 && _recommendation == null) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, RecommendationScreen(recommendationService: widget.recommendationService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${tipCount + articleCount}건', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ─── 뉴스 ────────────────────────────────────────

  Widget? _buildNewsLarge(ThemeData theme, String label) {
    if (_headlines.isEmpty) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, NewsScreen(newsService: widget.newsService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.newspaper_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            NewsTicker(
              headlines: _headlines,
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildNewsSmall(ThemeData theme, String label) {
    if (_headlines.isEmpty) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, NewsScreen(newsService: widget.newsService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.newspaper_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${_headlines.length}건', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ─── 날씨 ────────────────────────────────────────

  Widget? _buildWeatherLarge(ThemeData theme, String label) {
    if (_weather == null) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, WeatherScreen(weatherService: widget.weatherService, settingsService: widget.settingsService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_weather!.icon, size: 20, color: _weather!.iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label  ${_weather!.temperature.round()}° ${_weather!.description}',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_weather!.locationName.isNotEmpty) ...[
                  Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(_weather!.locationName, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.water_drop_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text('${_weather!.humidity}%', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildWeatherSmall(ThemeData theme, String label) {
    if (_weather == null) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, WeatherScreen(weatherService: widget.weatherService, settingsService: widget.settingsService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(_weather!.icon, size: 18, color: _weather!.iconColor),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text(
              '${_weather!.temperature.round()}° ${_weather!.description}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 루틴 ────────────────────────────────────────

  /// Check if a routine is active for today's work type.
  /// Returns true if: no work type assigned to today, or routine has no workTypeId, or matches.
  bool _isRoutineActiveForWorkType(dynamic r, String todayStr) {
    final todayWtId = widget.calendarService.getDateWorkType(todayStr);
    if (todayWtId == null) return true; // no work type assigned → all active
    if (r.workTypeId == null) return true; // routine has no work type → always active
    return r.workTypeId == todayWtId;
  }

  Widget _buildRoutineSmall(BuildContext context, DateTime now, String todayStr, String label) {
    final theme = Theme.of(context);
    final routines = widget.routineService.getAll();
    final active = routines.where((r) => r.isActiveOnDate(now)).toList();
    final matched = active.where((r) => _isRoutineActiveForWorkType(r, todayStr)).toList();
    final doneCount = matched.where((r) =>
        widget.completionService.isCompleted(r.id, todayStr) ||
        widget.completionService.isSkipped(r.id, todayStr)).length;
    final total = matched.length;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, RoutineListScreen(
        routineService: widget.routineService,
        completionService: widget.completionService,
        settingsService: widget.settingsService,
        alarmService: widget.alarmService,
        timerService: widget.timerService,
        routineGroupService: widget.routineGroupService,
        calendarService: widget.calendarService,
        onCompletionUnchecked: widget.onCompletionUnchecked,
        title: label,
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('$doneCount / $total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineLarge(BuildContext context, DateTime now, String todayStr, String label) {
    final theme = Theme.of(context);
    final routines = widget.routineService.getAll();
    final active = routines.where((r) => r.isActiveOnDate(now)).toList();
    final matched = active.where((r) => _isRoutineActiveForWorkType(r, todayStr)).toList();
    final doneCount = matched.where((r) =>
        widget.completionService.isCompleted(r.id, todayStr) ||
        widget.completionService.isSkipped(r.id, todayStr)).length;
    final total = matched.length;
    final progress = total > 0 ? doneCount / total : 0.0;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, RoutineListScreen(
        routineService: widget.routineService,
        completionService: widget.completionService,
        settingsService: widget.settingsService,
        alarmService: widget.alarmService,
        timerService: widget.timerService,
        routineGroupService: widget.routineGroupService,
        calendarService: widget.calendarService,
        onCompletionUnchecked: widget.onCompletionUnchecked,
        title: label,
      )),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('$doneCount / $total', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            if (active.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: active.take(6).map((r) {
                  final done = widget.completionService.isCompleted(r.id, todayStr) ||
                      widget.completionService.isSkipped(r.id, todayStr);
                  final isActiveWt = _isRoutineActiveForWorkType(r, todayStr);
                  return Opacity(
                    opacity: isActiveWt ? 1.0 : 0.35,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: done
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        r.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: done ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          fontWeight: done ? FontWeight.w600 : FontWeight.normal,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 할 일 ────────────────────────────────────────

  Widget _buildTodoSmall(BuildContext context, String label) {
    final theme = Theme.of(context);
    final count = widget.todoService.getIncomplete().length;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, TodoScreen(todoService: widget.todoService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.checklist, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${count}개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoLarge(BuildContext context, String label) {
    final theme = Theme.of(context);
    final incomplete = widget.todoService.getIncomplete();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, TodoScreen(todoService: widget.todoService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${incomplete.length}개', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            ...incomplete.take(3).map((t) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t.title, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ─── 명함 ────────────────────────────────────────

  Widget _buildCardSmall(BuildContext context, String label) {
    final theme = Theme.of(context);
    final card = widget.cardService.get();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, CardScreen(cardService: widget.cardService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.badge_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text(
              card != null && !card.isEmpty ? card.name : '미등록',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardLarge(BuildContext context, String label) {
    final theme = Theme.of(context);
    final card = widget.cardService.get();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, CardScreen(cardService: widget.cardService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: card == null || card.isEmpty
            ? Row(
                children: [
                  Icon(Icons.badge_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text('$label을 만들어보세요', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person, size: 22, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        if (card.position.isNotEmpty || card.company.isNotEmpty)
                          Text(
                            [card.position, card.company].where((s) => s.isNotEmpty).join(' | '),
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                ],
              ),
      ),
    );
  }

  // ─── 캘린더 (Enhanced) ────────────────────────────

  Widget _buildCalendarSmall(BuildContext context, DateTime now, String todayStr, String label) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, CalendarScreen(calendarService: widget.calendarService, routineService: widget.routineService, completionService: widget.completionService, settingsService: widget.settingsService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text(_calendarValue(todayStr, now), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarLarge(BuildContext context, DateTime now, String todayStr, String label) {
    final theme = Theme.of(context);
    final events = widget.calendarService.getByDate(todayStr);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, CalendarScreen(calendarService: widget.calendarService, routineService: widget.routineService, completionService: widget.completionService, settingsService: widget.settingsService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  events.isNotEmpty ? '오늘 ${events.length}건' : '${now.month}월',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                ),
              ],
            ),
            if (events.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...events.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(color: _parseColor(e.color), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(e.timeString, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.title, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 통계 (Enhanced) ──────────────────────────────

  Widget _buildStatsSmall(BuildContext context, DateTime now, String label) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, StatsScreen(routineService: widget.routineService, completionService: widget.completionService, distractionLogService: widget.distractionLogService, appDetectionService: widget.appDetection, healthService: widget.healthService, calendarService: widget.calendarService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${_weeklyPct(now)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsLarge(BuildContext context, DateTime now, String label) {
    final theme = Theme.of(context);
    final pct = _weeklyPct(now);
    final routines = widget.routineService.getAll();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, StatsScreen(routineService: widget.routineService, completionService: widget.completionService, distractionLogService: widget.distractionLogService, appDetectionService: widget.appDetection, healthService: widget.healthService, calendarService: widget.calendarService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('주간 $pct%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(7, (i) {
                final date = now.subtract(Duration(days: 6 - i));
                final dateStr = _formatDate(date);
                final active = routines.where((r) => r.isActiveOnDate(date)).toList();
                final done = active.where((r) =>
                    widget.completionService.isCompleted(r.id, dateStr) ||
                    widget.completionService.isSkipped(r.id, dateStr)).length;
                final dayPct = active.isNotEmpty ? done / active.length : 0.0;
                final isToday = i == 6;
                return Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 40,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 12,
                            height: (dayPct * 40).clamp(2.0, 40.0),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _weekdays[date.weekday - 1],
                        style: TextStyle(
                          fontSize: 10,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 알람 (Enhanced) ──────────────────────────────

  Widget _buildAlarmSmall(BuildContext context, String label) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, AlarmScreen(alarmService: widget.alarmService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.alarm_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${widget.alarmService.enabledCount}개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmLarge(BuildContext context, String label) {
    final theme = Theme.of(context);
    final alarms = widget.alarmService.getAll();
    final enabled = alarms.where((a) => a.isEnabled).toList();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, AlarmScreen(alarmService: widget.alarmService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alarm_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${enabled.length}개 활성', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
              ],
            ),
            if (enabled.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...enabled.take(3).map((a) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text(a.timeString, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.label, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                    Text(a.daysString, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 타이머 (Enhanced) ────────────────────────────

  Widget _buildTimerSmall(BuildContext context, String label) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, TimerScreen(timerService: widget.timerService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${widget.timerService.getAll().length}개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerLarge(BuildContext context, String label) {
    final theme = Theme.of(context);
    final timers = widget.timerService.getAll();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, TimerScreen(timerService: widget.timerService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${timers.length}개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
              ],
            ),
            if (timers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: timers.take(4).map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t.isPomodoro ? t.label : '${t.label} ${t.durationString}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 일기장 ──────────────────────────────────────

  Widget _buildDiarySmall(BuildContext context, String label) {
    final theme = Theme.of(context);
    final todayStr = _formatDate(DateTime.now());
    final todayDiary = widget.diaryService.getByDate(todayStr);
    final streak = widget.diaryService.getCurrentStreak();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, DiaryScreen(diaryService: widget.diaryService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_stories, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            if (todayDiary != null)
              Text(todayDiary.moodEmoji, style: const TextStyle(fontSize: 16))
            else
              Text('미작성', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            if (streak > 0) ...[
              const SizedBox(width: 6),
              Text('🔥$streak', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryLarge(BuildContext context, String label) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final todayDiary = widget.diaryService.getByDate(todayStr);
    final recent = widget.diaryService.getRecent(limit: 3);
    final streak = widget.diaryService.getCurrentStreak();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, DiaryScreen(diaryService: widget.diaryService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('🔥 $streak일 연속', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Today status
            if (todayDiary != null)
              Row(
                children: [
                  Text(todayDiary.moodEmoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      todayDiary.content.isNotEmpty ? todayDiary.content : '오늘의 일기',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.edit_note, size: 18, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Text('오늘의 일기를 작성해보세요', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            // Recent entries
            if (recent.length > 1) ...[
              const SizedBox(height: 8),
              ...recent.skip(todayDiary != null ? 1 : 0).take(2).map((d) {
                final parts = d.date.split('-');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Text(d.moodEmoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text('${parts[1]}/${parts[2]}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          d.content.isNotEmpty ? d.content : '(내용 없음)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 메모 (Enhanced) ──────────────────────────────

  Widget _buildMemoSmall(BuildContext context, String label) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, MemoListScreen(memoService: widget.memoService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.note_alt_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${widget.memoService.getAll().length}개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoLarge(BuildContext context, String label) {
    final theme = Theme.of(context);
    final memos = widget.memoService.getRecent(limit: 3);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, MemoListScreen(memoService: widget.memoService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note_alt_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${widget.memoService.getAll().length}개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
              ],
            ),
            if (memos.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...memos.map((m) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(m.title, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  // ─── D-Day ────────────────────────────────────────

  Widget? _buildDDaySmall(BuildContext context, DateTime now, String label) {
    final theme = Theme.of(context);
    final ddayEvents = widget.calendarService.getDDayEvents();
    final upcoming = ddayEvents.where((e) {
      final d = DateTime.tryParse(e.date);
      return d != null && !d.isBefore(DateTime(now.year, now.month, now.day));
    }).toList();
    if (upcoming.isEmpty) return null;
    final first = upcoming.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(first.dDayString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.error)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(first.title, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
          if (upcoming.length > 1)
            Text('+${upcoming.length - 1}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget? _buildDDayLarge(BuildContext context, DateTime now, String label) {
    final theme = Theme.of(context);
    final ddayEvents = widget.calendarService.getDDayEvents();
    final upcoming = ddayEvents.where((e) {
      final d = DateTime.tryParse(e.date);
      return d != null && !d.isBefore(DateTime(now.year, now.month, now.day));
    }).toList();
    if (upcoming.isEmpty) return null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          ...upcoming.take(3).map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(e.dDayString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.error)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.title, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── 자연소리 ──────────────────────────────────────

  Widget _buildNatureSmall(BuildContext context, String label) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, const NatureSceneScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.spa, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('7개 씬', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildNatureLarge(BuildContext context, String label) {
    final theme = Theme.of(context);
    final sceneNames = ['빗소리', '파도', '시냇물', '숲속', '모닥불', '바람', '밤벌레'];
    final sceneIcons = [Icons.water_drop, Icons.waves, Icons.water, Icons.forest, Icons.local_fire_department, Icons.air, Icons.nightlight_round];
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, const NatureSceneScreen()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${sceneNames.length}개 씬', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(sceneNames.length, (i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(sceneIcons[i], size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(sceneNames[i], style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 바로가기 ──────────────────────────────────────

  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');

  Future<void> _openBookmarkUrl(String url) async {
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (_) {}
  }

  Widget _bookmarkFavicon(String url, {double size = 22}) {
    try {
      final host = Uri.parse(url).host;
      final favUrl = 'https://www.google.com/s2/favicons?domain=$host&sz=64';
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          favUrl,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => Icon(Icons.public, size: size, color: AppColors.grey400),
        ),
      );
    } catch (_) {
      return Icon(Icons.public, size: size, color: AppColors.grey400);
    }
  }

  Widget _buildBookmarkSmall(BuildContext context, String label) {
    final theme = Theme.of(context);
    final bookmarks = widget.bookmarkService.getAll();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, BookmarkScreen(bookmarkService: widget.bookmarkService, title: label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.language, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${bookmarks.length}개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkLarge(BuildContext context, String label) {
    final theme = Theme.of(context);
    final bookmarks = widget.bookmarkService.getAll();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, BookmarkScreen(bookmarkService: widget.bookmarkService, title: label)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.language, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              ],
            ),
            if (bookmarks.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: bookmarks.map((bm) {
                  return GestureDetector(
                    onTap: () => _openBookmarkUrl(bm.url),
                    child: SizedBox(
                      width: 56,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: _bookmarkFavicon(bm.url, size: 24)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bm.name,
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Layout helpers ───────────────────────────────

  static const _defaultLabels = {
    'recommend': '맞춤 정보', 'news': '뉴스', 'weather': '날씨', 'routine': '루틴', 'todo': '할 일',
    'diary': '일기장', 'card': '명함', 'calendar': '캘린더', 'stats': '통계', 'alarm': '알람',
    'timer': '타이머', 'memo': '메모', 'dday': 'D-Day', 'nature': '자연소리', 'bookmark': '바로가기', 'fortune': '오늘의 운세', 'goal': '목표',
  };

  String _sectionLabel(String id) {
    final baseId = SettingsService.sectionBaseId(id);
    return widget.settingsService.getSectionLabel(id) ?? _defaultLabels[baseId] ?? baseId;
  }

  IconData _sectionIcon(String id) {
    const icons = {
      'recommend': Icons.auto_awesome_outlined, 'news': Icons.newspaper_outlined, 'weather': Icons.wb_sunny_outlined,
      'routine': Icons.check_circle_outline, 'todo': Icons.checklist,
      'card': Icons.badge_outlined, 'calendar': Icons.calendar_month_outlined,
      'stats': Icons.bar_chart_rounded, 'alarm': Icons.alarm_rounded,
      'timer': Icons.timer_outlined, 'memo': Icons.note_alt_outlined,
      'dday': Icons.event_outlined, 'diary': Icons.auto_stories, 'nature': Icons.spa,
      'bookmark': Icons.language, 'fortune': Icons.auto_awesome, 'goal': Icons.track_changes,
    };
    final baseId = SettingsService.sectionBaseId(id);
    return icons[baseId] ?? Icons.widgets_outlined;
  }

  // ─── 오늘의 운세 ────────────────────────────────────

  void _openFortune(BuildContext context, String label) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FortuneScreen(fortuneService: widget.fortuneService, title: label),
    )).then((_) {
      // Refresh after returning (user may have set profile)
      final newFortune = widget.fortuneService.generateTodayFortune();
      if (mounted && newFortune != null) setState(() => _fortune = newFortune);
    });
  }

  Color _fortuneScoreColor(int score, ThemeData theme) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return theme.colorScheme.primary;
    if (score >= 45) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }

  Widget? _buildFortuneSmall(BuildContext context, ThemeData theme, String label) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openFortune(context, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                overflow: TextOverflow.ellipsis),
            ),
            if (_fortune != null) ...[
              Text(_fortune!.overallLabel,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: _fortuneScoreColor(_fortune!.overallScore, theme))),
              const SizedBox(width: 4),
              Text('${_fortune!.overallScore}점',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
            ] else
              Text('설정하기', style: TextStyle(fontSize: 13, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  Widget? _buildFortuneLarge(BuildContext context, ThemeData theme, String label) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openFortune(context, label),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _fortune != null ? _buildFortuneLargeContent(theme, label) : _buildFortuneSetup(theme, label),
      ),
    );
  }

  Widget _buildFortuneSetup(ThemeData theme, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 16),
        Icon(Icons.auto_awesome, size: 40, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
        const SizedBox(height: 8),
        Text('생년월일을 입력하고\n오늘의 운세를 확인하세요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildFortuneLargeContent(ThemeData theme, String label) {
    final f = _fortune!;
    final color = _fortuneScoreColor(f.overallScore, theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (f.lunarDateStr.isNotEmpty)
              Text(f.lunarDateStr, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 12),
        // Score + label
        Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Center(
                child: Text('${f.overallScore}', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.overallLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 2),
                  Text(f.todayAdvice,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Category mini bars
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: f.categoryScores.entries.map((e) {
            final catColor = _fortuneScoreColor(e.value, theme);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                  Text(e.key, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 3),
                  Text('${e.value}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: catColor)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── 목표 섹션 ───
  void _openGoal(BuildContext context, String label) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GoalScreen(
        goalService: widget.goalService,
        routineService: widget.routineService,
        completionService: widget.completionService,
        todoService: widget.todoService,
        title: label,
      ),
    ));
  }

  Widget? _buildGoalSmall(BuildContext context, ThemeData theme, String label) {
    final all = widget.goalService.getAll();
    final completed = all.where((g) => g.isCompleted).length;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openGoal(context, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.track_changes, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis),
            ),
            if (all.isNotEmpty)
              Text('$completed / ${all.length}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant))
            else
              Text('추가하기', style: TextStyle(fontSize: 13, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  Widget? _buildGoalLarge(BuildContext context, ThemeData theme, String label) {
    final all = widget.goalService.getAll();
    final incomplete = all.where((g) => !g.isCompleted).toList();
    final progress = widget.goalService.getOverallProgress(widget.completionService, widget.todoService);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openGoal(context, label),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                Text('${all.where((g) => g.isCompleted).length} / ${all.length}',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            if (all.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 10),
              ...incomplete.take(3).map((g) {
                final gProgress = widget.goalService.getProgress(g, widget.completionService, widget.todoService);
                final catColor = Goal.categoryColor(g.category);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Goal.categoryIcon(g.category), size: 14, color: catColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(g.title, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text('${(gProgress * 100).round()}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: catColor)),
                    ],
                  ),
                );
              }),
            ] else ...[
              const SizedBox(height: 12),
              Center(
                child: Text('목표를 추가하고\n루틴과 할일을 연결해보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSectionOptions(String id) {
    final theme = Theme.of(context);
    final isHalf = widget.settingsService.isDashboardSectionHalf(id);
    final isDuplicate = SettingsService.isDuplicate(id);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(_sectionLabel(id), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _optionCard(ctx, theme, icon: Icons.fullscreen, label: '전체', selected: !isHalf, onTap: () async {
                      await widget.settingsService.setDashboardSectionHalf(id, false);
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() {});
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _optionCard(ctx, theme, icon: Icons.splitscreen, label: '반쪽', selected: isHalf, onTap: () async {
                      await widget.settingsService.setDashboardSectionHalf(id, true);
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() {});
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showRenameDialog(id);
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('이름 변경'),
                ),
              ),
              if (_editMode)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () async {
                      final baseId = SettingsService.sectionBaseId(id);
                      final newId = '$baseId:${DateTime.now().millisecondsSinceEpoch}';
                      final order = widget.settingsService.dashboardOrder;
                      final idx = order.indexOf(id);
                      if (idx >= 0) {
                        order.insert(idx + 1, newId);
                      } else {
                        order.add(newId);
                      }
                      await widget.settingsService.setDashboardOrder(order);
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() {});
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('복제'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    await widget.settingsService.setDashboardSectionHidden(id, true);
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                  },
                  icon: Icon(Icons.visibility_off, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  label: Text('숨기기', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ),
              ),
              if (isDuplicate)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () async {
                      final order = widget.settingsService.dashboardOrder;
                      order.remove(id);
                      await widget.settingsService.setDashboardOrder(order);
                      // Clean up related settings
                      await widget.settingsService.setSectionLabel(id, '');
                      await widget.settingsService.setDashboardSectionHidden(id, false);
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() {});
                    },
                    icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                    label: Text('삭제', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(String id) {
    final controller = TextEditingController(text: _sectionLabel(id));
    final baseId = SettingsService.sectionBaseId(id);
    final defaultLabel = _defaultLabels[baseId] ?? baseId;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: defaultLabel,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) async {
            final name = controller.text.trim();
            await widget.settingsService.setSectionLabel(
              id,
              name == defaultLabel ? '' : name,
            );
            if (ctx.mounted) Navigator.pop(ctx);
            setState(() {});
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await widget.settingsService.setSectionLabel(id, '');
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('기본값'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              await widget.settingsService.setSectionLabel(
                id,
                name == defaultLabel ? '' : name,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _toggleSectionSize(String id) async {
    await widget.settingsService.toggleDashboardSectionSize(id);
    setState(() {});
  }

  Widget _optionCard(BuildContext ctx, ThemeData theme, {
    required IconData icon, required String label, required bool selected, required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)) : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.info;
    }
  }

  // ─── Build ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final order = widget.settingsService.dashboardOrder;

    final hidden = widget.settingsService.dashboardHidden;
    final visible = <String>[];
    final sectionWidgets = <String, Widget>{};
    for (final id in order) {
      if (hidden.contains(id)) continue;
      final w = _buildSection(id, context, now, todayStr, theme);
      if (w != null) {
        visible.add(id);
        sectionWidgets[id] = w;
      }
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: SafeArea(bottom: false, child: SizedBox(height: 8)),
            ),
            if (_editMode)
              _buildEditSliver(visible, order, theme)
            else
              _buildNormalSliver(visible, sectionWidgets),
            if (_editMode && hidden.isNotEmpty)
              _buildHiddenSliver(hidden, theme),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.small(
            onPressed: () => setState(() => _editMode = !_editMode),
            child: Icon(_editMode ? Icons.check : Icons.dashboard_customize_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalSliver(List<String> visible, Map<String, Widget> sectionWidgets) {
    final List<Widget> rows = [];
    int i = 0;
    while (i < visible.length) {
      final id = visible[i];
      final isHalf = widget.settingsService.isDashboardSectionHalf(id);
      if (!isHalf) {
        rows.add(
          GestureDetector(
            onLongPress: () => _showSectionOptions(id),
            onDoubleTap: () => _toggleSectionSize(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: sectionWidgets[id]!,
            ),
          ),
        );
        i++;
      } else {
        if (i + 1 < visible.length && widget.settingsService.isDashboardSectionHalf(visible[i + 1])) {
          final id2 = visible[i + 1];
          rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () => _showSectionOptions(id),
                      onDoubleTap: () => _toggleSectionSize(id),
                      child: sectionWidgets[id]!,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () => _showSectionOptions(id2),
                      onDoubleTap: () => _toggleSectionSize(id2),
                      child: sectionWidgets[id2]!,
                    ),
                  ),
                ],
              ),
            ),
          );
          i += 2;
        } else {
          rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () => _showSectionOptions(id),
                      onDoubleTap: () => _toggleSectionSize(id),
                      child: sectionWidgets[id]!,
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          );
          i++;
        }
      }
    }
    return SliverList(delegate: SliverChildListDelegate(rows));
  }

  Widget _buildEditSliver(List<String> visible, List<String> order, ThemeData theme) {
    final now = DateTime.now();
    final todayStr = _formatDate(now);

    return SliverReorderableList(
      itemCount: visible.length,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = visible.removeAt(oldIndex);
          visible.insert(newIndex, item);
          final newOrder = List<String>.from(visible);
          for (final id in order) {
            if (!newOrder.contains(id)) newOrder.add(id);
          }
          widget.settingsService.setDashboardOrder(newOrder);
        });
      },
      itemBuilder: (context, index) {
        final id = visible[index];
        final sectionWidget = _buildSection(id, context, now, todayStr, theme);
        if (sectionWidget == null) {
          return SizedBox.shrink(key: ValueKey(id));
        }
        final isHalf = widget.settingsService.isDashboardSectionHalf(id);
        return ReorderableDragStartListener(
          key: ValueKey(id),
          index: index,
          child: GestureDetector(
            onTap: () => _showSectionOptions(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: isHalf
                  ? Row(
                      children: [
                        Expanded(child: AbsorbPointer(child: sectionWidget)),
                        const SizedBox(width: 8),
                        const Expanded(child: SizedBox()),
                      ],
                    )
                  : AbsorbPointer(child: sectionWidget),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHiddenSliver(Set<String> hidden, ThemeData theme) {
    final hiddenList = widget.settingsService.dashboardOrder
        .where((id) => hidden.contains(id))
        .toList();
    if (hiddenList.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('숨긴 섹션', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hiddenList.map((id) => ActionChip(
                avatar: Icon(_sectionIcon(id), size: 16),
                label: Text(_sectionLabel(id)),
                onPressed: () async {
                  await widget.settingsService.setDashboardSectionHidden(id, false);
                  setState(() {});
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────

  int _weeklyPct(DateTime now) {
    final routines = widget.routineService.getAll();
    int totalActive = 0, totalDone = 0;
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _formatDate(date);
      final active = routines.where((r) => r.isActiveOnDate(date)).toList();
      totalActive += active.length;
      totalDone += active.where((r) =>
          widget.completionService.isCompleted(r.id, dateStr) ||
          widget.completionService.isSkipped(r.id, dateStr)).length;
    }
    return totalActive > 0 ? (totalDone / totalActive * 100).round() : 0;
  }

  String _calendarValue(String todayStr, DateTime now) {
    final count = widget.calendarService.countByDate(todayStr);
    return count > 0 ? '오늘 ${count}건' : '${now.month}월';
  }

  Future<void> _push(BuildContext context, Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }
}
