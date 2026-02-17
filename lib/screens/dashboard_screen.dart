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
import '../services/weather_service.dart';
import '../services/news_service.dart';
import '../models/weather_data.dart';
import '../widgets/news_ticker.dart';
import 'routine_list_screen.dart';
import 'todo_screen.dart';
import 'memo_list_screen.dart';
import 'stats_screen.dart';
import 'alarm_screen.dart';
import 'timer_screen.dart';
import 'calendar_screen.dart';

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
  final WeatherService weatherService;
  final NewsService newsService;
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
    required this.weatherService,
    required this.newsService,
    this.onCompletionUnchecked,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  WeatherData? _weather;
  List<String> _headlines = [];

  @override
  void initState() {
    super.initState();
    _headlines = widget.newsService.getCached();
    _loadWeather();
    _loadNews();
  }

  Future<void> _loadWeather() async {
    final data = await widget.weatherService.fetchCurrent();
    if (mounted && data != null) setState(() => _weather = data);
  }

  Future<void> _loadNews() async {
    final list = await widget.newsService.fetchHeadlines();
    if (mounted && list.isNotEmpty) setState(() => _headlines = list);
  }

  void refresh() {
    if (mounted) setState(() {});
    _loadWeather();
    _loadNews();
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final weekday = _weekdays[now.weekday - 1];

    return CustomScrollView(
      slivers: [
        // ─── 헤더: 뉴스 티커 ──────────────────────
        if (_headlines.isNotEmpty)
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: NewsTicker(
                  headlines: _headlines,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        if (_headlines.isEmpty)
          const SliverToBoxAdapter(
            child: SafeArea(bottom: false, child: SizedBox(height: 16)),
          ),

        // ─── 루틴 진행률 ─────────────────────────
        SliverToBoxAdapter(
          child: _buildRoutineSection(context, now, todayStr),
        ),

        // ─── 할 일 ───────────────────────────────
        SliverToBoxAdapter(
          child: _buildTodoSection(context),
        ),

        // ─── 유틸리티 그리드 (알람 / 타이머 / 캘린더 / 통계 / 메모) ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
            ),
            delegate: SliverChildListDelegate([
              _buildGridTile(
                context,
                icon: Icons.calendar_month_outlined,
                label: '캘린더',
                value: _calendarValue(todayStr, now),
                onTap: () => _push(context, CalendarScreen(
                  calendarService: widget.calendarService,
                  routineService: widget.routineService,
                  completionService: widget.completionService,
                  settingsService: widget.settingsService,
                )),
              ),
              _buildGridTile(
                context,
                icon: Icons.bar_chart_rounded,
                label: '통계',
                value: '${_weeklyPct(now)}%',
                onTap: () => _push(context, StatsScreen(
                  routineService: widget.routineService,
                  completionService: widget.completionService,
                  distractionLogService: widget.distractionLogService,
                  appDetectionService: widget.appDetection,
                  healthService: widget.healthService,
                )),
              ),
              _buildGridTile(
                context,
                icon: Icons.alarm_rounded,
                label: '알람',
                value: '${widget.alarmService.enabledCount}개',
                onTap: () => _push(context, AlarmScreen(alarmService: widget.alarmService)),
              ),
              _buildGridTile(
                context,
                icon: Icons.timer_outlined,
                label: '타이머',
                value: '${widget.timerService.getAll().length}개',
                onTap: () => _push(context, TimerScreen(timerService: widget.timerService)),
              ),
              _buildGridTile(
                context,
                icon: Icons.note_alt_outlined,
                label: '메모',
                value: '${widget.memoService.getAll().length}개',
                onTap: () => _push(context, MemoListScreen(memoService: widget.memoService)),
              ),
            ]),
          ),
        ),

        // ─── D-Day ────────────────────────────────
        SliverToBoxAdapter(child: _buildDDaySection(context, now)),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ─── 루틴 섹션 ─────────────────────────────────

  Widget _buildRoutineSection(BuildContext context, DateTime now, String todayStr) {
    final theme = Theme.of(context);
    final routines = widget.routineService.getAll();
    final active = routines.where((r) => r.isActiveOnDate(now)).toList();
    final doneCount = active.where((r) =>
        widget.completionService.isCompleted(r.id, todayStr) ||
        widget.completionService.isSkipped(r.id, todayStr)).length;
    final total = active.length;
    final progress = total > 0 ? doneCount / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _push(context, RoutineListScreen(
          routineService: widget.routineService,
          completionService: widget.completionService,
          settingsService: widget.settingsService,
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
                  Text(
                    '오늘의 루틴',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '$doneCount / $total',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
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
      ),
    );
  }

  // ─── 할 일 섹션 ──────────────────────────────────

  Widget _buildTodoSection(BuildContext context) {
    final theme = Theme.of(context);
    final incomplete = widget.todoService.getIncomplete();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: InkWell(
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
                  Text(
                    '할 일',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${incomplete.length}개',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...incomplete.take(3).map((t) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.title,
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 그리드 타일 ─────────────────────────────────

  Widget _buildGridTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── D-Day 섹션 ─────────────────────────────────

  Widget _buildDDaySection(BuildContext context, DateTime now) {
    final theme = Theme.of(context);
    final ddayEvents = widget.calendarService.getDDayEvents();
    final upcoming = ddayEvents.where((e) {
      final d = DateTime.tryParse(e.date);
      return d != null && !d.isBefore(DateTime(now.year, now.month, now.day));
    }).toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'D-Day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
                  child: Text(
                    e.dDayString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.title,
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
        ],
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
