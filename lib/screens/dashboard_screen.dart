import 'package:flutter/material.dart';
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
    this.onCompletionUnchecked,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  List<String> _headlines = [];
  WeatherData? _weather;
  RecommendationData? _recommendation;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _headlines = widget.newsService.getCached();
    _weather = widget.weatherService.getCached();
    _recommendation = widget.recommendationService.getCached();
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
    switch (id) {
      case 'recommend':
        return large ? _buildRecommendLarge(theme) : _buildRecommendSmall(theme);
      case 'news':
        return large ? _buildNewsLarge(theme) : _buildNewsSmall(theme);
      case 'weather':
        return large ? _buildWeatherLarge(theme) : _buildWeatherSmall(theme);
      case 'routine':
        return large ? _buildRoutineLarge(context, now, todayStr) : _buildRoutineSmall(context, now, todayStr);
      case 'todo':
        return large ? _buildTodoLarge(context) : _buildTodoSmall(context);
      case 'card':
        return large ? _buildCardLarge(context) : _buildCardSmall(context);
      case 'calendar':
        return large ? _buildCalendarLarge(context, now, todayStr) : _buildCalendarSmall(context, now, todayStr);
      case 'stats':
        return large ? _buildStatsLarge(context, now) : _buildStatsSmall(context, now);
      case 'alarm':
        return large ? _buildAlarmLarge(context) : _buildAlarmSmall(context);
      case 'timer':
        return large ? _buildTimerLarge(context) : _buildTimerSmall(context);
      case 'memo':
        return large ? _buildMemoLarge(context) : _buildMemoSmall(context);
      case 'dday':
        return large ? _buildDDayLarge(context, now) : _buildDDaySmall(context, now);
      default:
        return null;
    }
  }

  // ─── 맞춤 정보 ──────────────────────────────────────

  Widget? _buildRecommendLarge(ThemeData theme) {
    final tipCount = _recommendation?.tips.length ?? 0;
    final articleCount = _recommendation?.articles.length ?? 0;
    if (tipCount == 0 && articleCount == 0 && _recommendation == null) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, RecommendationScreen(recommendationService: widget.recommendationService)),
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
                Text('맞춤 정보', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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

  Widget? _buildRecommendSmall(ThemeData theme) {
    final tipCount = _recommendation?.tips.length ?? 0;
    final articleCount = _recommendation?.articles.length ?? 0;
    if (tipCount == 0 && articleCount == 0 && _recommendation == null) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, RecommendationScreen(recommendationService: widget.recommendationService)),
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
            Text('맞춤 정보', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${tipCount + articleCount}건', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ─── 뉴스 ────────────────────────────────────────

  Widget? _buildNewsLarge(ThemeData theme) {
    if (_headlines.isEmpty) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, NewsScreen(newsService: widget.newsService)),
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
                Text('뉴스', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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

  Widget? _buildNewsSmall(ThemeData theme) {
    if (_headlines.isEmpty) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, NewsScreen(newsService: widget.newsService)),
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
            Text('뉴스', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${_headlines.length}건', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ─── 날씨 ────────────────────────────────────────

  Widget? _buildWeatherLarge(ThemeData theme) {
    if (_weather == null) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, WeatherScreen(weatherService: widget.weatherService, settingsService: widget.settingsService)),
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
                    '날씨  ${_weather!.temperature.round()}° ${_weather!.description}',
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

  Widget? _buildWeatherSmall(ThemeData theme) {
    if (_weather == null) return null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, WeatherScreen(weatherService: widget.weatherService, settingsService: widget.settingsService)),
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
            Text('날씨', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
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

  Widget _buildRoutineSmall(BuildContext context, DateTime now, String todayStr) {
    final theme = Theme.of(context);
    final routines = widget.routineService.getAll();
    final active = routines.where((r) => r.isActiveOnDate(now)).toList();
    final doneCount = active.where((r) =>
        widget.completionService.isCompleted(r.id, todayStr) ||
        widget.completionService.isSkipped(r.id, todayStr)).length;
    final total = active.length;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, RoutineListScreen(
        routineService: widget.routineService,
        completionService: widget.completionService,
        settingsService: widget.settingsService,
        timerService: widget.timerService,
        onCompletionUnchecked: widget.onCompletionUnchecked,
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
            Text('루틴', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('$doneCount / $total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineLarge(BuildContext context, DateTime now, String todayStr) {
    final theme = Theme.of(context);
    final routines = widget.routineService.getAll();
    final active = routines.where((r) => r.isActiveOnDate(now)).toList();
    final doneCount = active.where((r) =>
        widget.completionService.isCompleted(r.id, todayStr) ||
        widget.completionService.isSkipped(r.id, todayStr)).length;
    final total = active.length;
    final progress = total > 0 ? doneCount / total : 0.0;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, RoutineListScreen(
        routineService: widget.routineService,
        completionService: widget.completionService,
        settingsService: widget.settingsService,
        timerService: widget.timerService,
        onCompletionUnchecked: widget.onCompletionUnchecked,
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
                Text('오늘의 루틴', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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
                  return Container(
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

  Widget _buildTodoSmall(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.todoService.getIncomplete().length;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, TodoScreen(todoService: widget.todoService)),
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
            Text('할 일', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${count}개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoLarge(BuildContext context) {
    final theme = Theme.of(context);
    final incomplete = widget.todoService.getIncomplete();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, TodoScreen(todoService: widget.todoService)),
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
                Text('할 일', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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

  Widget _buildCardSmall(BuildContext context) {
    final theme = Theme.of(context);
    final card = widget.cardService.get();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, CardScreen(cardService: widget.cardService)),
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
            Text('명함', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
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

  Widget _buildCardLarge(BuildContext context) {
    final theme = Theme.of(context);
    final card = widget.cardService.get();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, CardScreen(cardService: widget.cardService)),
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
                  Text('명함을 만들어보세요', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
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

  Widget _buildCalendarSmall(BuildContext context, DateTime now, String todayStr) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, CalendarScreen(calendarService: widget.calendarService, routineService: widget.routineService, completionService: widget.completionService, settingsService: widget.settingsService)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('캘린더', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text(_calendarValue(todayStr, now), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarLarge(BuildContext context, DateTime now, String todayStr) {
    final theme = Theme.of(context);
    final events = widget.calendarService.getByDate(todayStr);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, CalendarScreen(calendarService: widget.calendarService, routineService: widget.routineService, completionService: widget.completionService, settingsService: widget.settingsService)),
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
                Text('캘린더', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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

  Widget _buildStatsSmall(BuildContext context, DateTime now) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, StatsScreen(routineService: widget.routineService, completionService: widget.completionService, distractionLogService: widget.distractionLogService, appDetectionService: widget.appDetection, healthService: widget.healthService)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('통계', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${_weeklyPct(now)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsLarge(BuildContext context, DateTime now) {
    final theme = Theme.of(context);
    final pct = _weeklyPct(now);
    final routines = widget.routineService.getAll();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, StatsScreen(routineService: widget.routineService, completionService: widget.completionService, distractionLogService: widget.distractionLogService, appDetectionService: widget.appDetection, healthService: widget.healthService)),
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
                Text('통계', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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

  Widget _buildAlarmSmall(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, AlarmScreen(alarmService: widget.alarmService)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.alarm_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('알람', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${widget.alarmService.enabledCount}개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmLarge(BuildContext context) {
    final theme = Theme.of(context);
    final alarms = widget.alarmService.getAll();
    final enabled = alarms.where((a) => a.isEnabled).toList();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, AlarmScreen(alarmService: widget.alarmService)),
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
                Text('알람', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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

  Widget _buildTimerSmall(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, TimerScreen(timerService: widget.timerService)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('타이머', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${widget.timerService.getAll().length}개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerLarge(BuildContext context) {
    final theme = Theme.of(context);
    final timers = widget.timerService.getAll();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, TimerScreen(timerService: widget.timerService)),
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
                Text('타이머', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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

  // ─── 메모 (Enhanced) ──────────────────────────────

  Widget _buildMemoSmall(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(context, MemoListScreen(memoService: widget.memoService)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.note_alt_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('메모', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const Spacer(),
            Text('${widget.memoService.getAll().length}개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoLarge(BuildContext context) {
    final theme = Theme.of(context);
    final memos = widget.memoService.getRecent(limit: 3);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(context, MemoListScreen(memoService: widget.memoService)),
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
                Text('메모', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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

  Widget? _buildDDaySmall(BuildContext context, DateTime now) {
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

  Widget? _buildDDayLarge(BuildContext context, DateTime now) {
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
          Text('D-Day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
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

  // ─── Layout helpers ───────────────────────────────

  String _sectionLabel(String id) {
    const labels = {
      'recommend': '맞춤 정보', 'news': '뉴스', 'weather': '날씨', 'routine': '루틴', 'todo': '할 일',
      'card': '명함', 'calendar': '캘린더', 'stats': '통계', 'alarm': '알람',
      'timer': '타이머', 'memo': '메모', 'dday': 'D-Day',
    };
    return labels[id] ?? id;
  }

  IconData _sectionIcon(String id) {
    const icons = {
      'recommend': Icons.auto_awesome_outlined, 'news': Icons.newspaper_outlined, 'weather': Icons.wb_sunny_outlined,
      'routine': Icons.check_circle_outline, 'todo': Icons.checklist,
      'card': Icons.badge_outlined, 'calendar': Icons.calendar_month_outlined,
      'stats': Icons.bar_chart_rounded, 'alarm': Icons.alarm_rounded,
      'timer': Icons.timer_outlined, 'memo': Icons.note_alt_outlined,
      'dday': Icons.event_outlined,
    };
    return icons[id] ?? Icons.widgets_outlined;
  }

  void _showSectionOptions(String id) {
    final theme = Theme.of(context);
    final isHalf = widget.settingsService.isDashboardSectionHalf(id);
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
                  onPressed: () async {
                    await widget.settingsService.setDashboardSectionHidden(id, true);
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                  },
                  icon: Icon(Icons.visibility_off, size: 18, color: theme.colorScheme.error),
                  label: Text('숨기기', style: TextStyle(color: theme.colorScheme.error)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
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
      return Colors.blue;
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
