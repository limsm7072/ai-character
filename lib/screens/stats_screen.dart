import 'package:flutter/material.dart';
import '../models/routine.dart' as model;
import '../services/routine_service.dart';
import '../services/routine_completion_service.dart';
import '../services/distraction_log_service.dart';
import '../services/app_detection_service.dart';
import '../services/health_service.dart';
import '../models/distraction_log.dart';
import 'routine_stats_screen.dart';

class StatsScreen extends StatefulWidget {
  final RoutineService routineService;
  final RoutineCompletionService completionService;
  final DistractionLogService distractionLogService;
  final AppDetectionService? appDetectionService;
  final HealthService? healthService;
  final int initialTab;

  const StatsScreen({
    super.key,
    required this.routineService,
    required this.completionService,
    required this.distractionLogService,
    this.appDetectionService,
    this.healthService,
    this.initialTab = 0,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _appUsageLoading = false;
  bool? _hasUsagePermission;
  List<_DayUsageData> _weeklyDayData = [];
  Duration _prevWeekTotal = Duration.zero;
  int? _selectedDayIndex;
  String? _selectedAppFilter;

  // 딴짓 탭 필터: 0=오늘, 1=이번 주, 2=전체
  int _distractionFilter = 0;

  // 앱 사용 통계에서 제외할 패키지 (시스템/유틸리티)
  static const _hiddenAppPrefixes = [
    'com.android.',
    'com.google.android.inputmethod',
    'com.google.android.gms',
    'com.google.android.gsf',
    'com.google.android.providers',
    'com.google.android.ext.',
    'com.google.android.overlay',
    'com.google.android.packageinstaller',
    'com.google.android.permissioncontroller',
    'com.samsung.android.lool',       // Device care
    'com.samsung.android.themecenter',
    'com.samsung.android.app.routines',
    'com.samsung.android.dialer',
    'com.samsung.android.incallui',
    'com.samsung.android.server.',
    'com.samsung.android.oneui',
    'com.sec.android.',
    'android',
  ];
  static const _hiddenAppPackages = {
    'com.burockgames.timeclocker',     // StayFree
    'com.stayfreeapps.android',        // StayFree (alt)
    'com.zerodesktop.appdetox',        // AppDetox
    'com.yoongoo.screentime',          // Screen Time
    'com.aicharacter.ai_character',    // 자기 자신
    'com.google.android.apps.wellbeing', // Digital Wellbeing
  };

  bool _isHiddenApp(String pkg) {
    if (_hiddenAppPackages.contains(pkg)) return true;
    for (final prefix in _hiddenAppPrefixes) {
      if (pkg.startsWith(prefix)) return true;
    }
    return false;
  }

  // 건강 탭
  bool _healthLoading = false;
  bool _healthLoaded = false;
  int _todaySteps = 0;
  List<DailySteps> _weeklySteps = [];
  SleepData? _sleepData;
  HeartRateData? _heartRate;
  HeartRateRange? _heartRateRange;

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
      length: 4,
      initialIndex: widget.initialTab,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: const Text('통계'),
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            bottom: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
              isScrollable: false,
              tabs: const [
                Tab(text: '완료율'),
                Tab(text: '딴짓'),
                Tab(text: '앱 사용'),
                Tab(text: '건강'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _buildCompletionTab(),
            _buildDistractionTab(),
            _buildAppUsageTab(),
            _buildHealthTab(),
          ],
        ),
      ),
    ),
    );
  }

  // ==================== 완료율 탭 ====================

  Widget _buildCompletionTab() {
    final routines = widget.routineService.getAll();
    final today = widget.completionService.todayStr();

    if (routines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '루틴을 추가하면 완료율을 볼 수 있어요',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. 원형 프로그레스
        _buildCircularProgressRow(routines, today),
        const SizedBox(height: 20),

        // 2. 연속 달성 스트릭
        _buildStreakCard(routines),
        const SizedBox(height: 20),

        // 3. 월간 히트맵
        _buildMonthlyHeatmapCard(routines),
        const SizedBox(height: 24),

        // 4. 루틴별 카드
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '루틴별 완료율 (최근 30일)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...routines.map((r) => _buildRoutineCard(r)),
        const SizedBox(height: 16),
      ],
    );
  }

  // --- 원형 프로그레스 ---

  /// Filter routines active on a specific date (checks startDate + activeDays).
  List<model.Routine> _activeRoutinesOn(List<model.Routine> routines, DateTime date) {
    return routines.where((r) => r.isActiveOnDate(date)).toList();
  }

  /// Calculate completion rate over N days, only counting days each routine is active.
  double _calcRate(List<model.Routine> routines, int days) {
    if (routines.isEmpty || days <= 0) return 0.0;
    final now = DateTime.now();
    int totalSlots = 0;
    int completedSlots = 0;

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _formatDate(date);
      final active = _activeRoutinesOn(routines, date);
      totalSlots += active.length;
      for (final r in active) {
        if (widget.completionService.isCompleted(r.id, dateStr)) {
          completedSlots++;
        }
      }
    }
    return totalSlots > 0 ? completedSlots / totalSlots : 0.0;
  }

  Widget _buildCircularProgressRow(
      List<model.Routine> routines, String today) {
    final now = DateTime.now();
    final todayActive = _activeRoutinesOn(routines, now);
    final todayCompleted = todayActive
        .where((r) => widget.completionService.isCompleted(r.id, today))
        .length;
    final todayRate =
        todayActive.isNotEmpty ? todayCompleted / todayActive.length : 0.0;

    final weekRate = _calcRate(routines, 7);
    final monthRate = _calcRate(routines, 30);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCircularGauge(
          label: '오늘',
          rate: todayRate,
          detail: '$todayCompleted/${todayActive.length}',
          color: Colors.teal,
        ),
        _buildCircularGauge(
          label: '이번 주',
          rate: weekRate,
          color: Colors.blue,
        ),
        _buildCircularGauge(
          label: '이번 달',
          rate: monthRate,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildCircularGauge({
    required String label,
    required double rate,
    String? detail,
    required Color color,
  }) {
    final percentage = (rate * 100).round();
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: rate,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
                backgroundColor: color.withOpacity(0.12),
                color: color,
              ),
              Center(
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        if (detail != null)
          Text(detail,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  // --- 스트릭 ---

  Widget _buildStreakCard(List<model.Routine> routines) {
    final streak = _calculateStreak(routines);
    final hasStreak = streak > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              hasStreak ? Icons.local_fire_department : Icons.bedtime_outlined,
              size: 32,
              color: hasStreak ? Colors.deepOrange : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasStreak
                        ? '$streak일 연속 달성 중!'
                        : '연속 달성 기록이 없어요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasStreak ? Colors.deepOrange : Colors.grey,
                    ),
                  ),
                  Text(
                    hasStreak ? '매일 꾸준히 하고 있어요!' : '오늘부터 시작해보세요',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateStreak(List<model.Routine> routines) {
    if (routines.isEmpty) return 0;

    // Only consider routines that have at least one completion record,
    // so newly added routines don't break the streak retroactively.
    final trackedRoutines = routines.where((r) {
      if (!r.isEnabled) return false;
      final rate = _calcRoutineRate(r, 60);
      return rate > 0;
    }).toList();
    if (trackedRoutines.isEmpty) return 0;

    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _formatDate(date);
      final dayIndex = date.weekday - 1;

      final activeRoutines = trackedRoutines
          .where((r) => r.isActiveOnDate(date))
          .toList();

      // No tracked routines active on this day — skip, don't break
      if (activeRoutines.isEmpty) continue;

      final allCompleted = activeRoutines.every(
          (r) => widget.completionService.isCompleted(r.id, dateStr));

      if (allCompleted) {
        streak++;
      } else {
        // Today might not be done yet — skip
        if (i == 0) continue;
        break;
      }
    }
    return streak;
  }

  // --- 월간 히트맵 ---

  Widget _buildMonthlyHeatmapCard(List<model.Routine> routines) {
    final now = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${now.year}년 ${now.month}월 달성 현황',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMonthlyHeatmapGrid(routines),
            const SizedBox(height: 10),
            _buildHeatmapLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyHeatmapGrid(List<model.Routine> routines) {
    final now = DateTime.now();
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];

    // Current month: 1st to last day, aligned to week grid (Mon-Sun)
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final lastOfMonth = DateTime(now.year, now.month + 1, 0);
    // Start grid from Monday of the week containing the 1st
    final gridStart = firstOfMonth.subtract(
        Duration(days: (firstOfMonth.weekday - 1) % 7));
    // End grid on Sunday of the week containing the last day
    final gridEnd = lastOfMonth.add(
        Duration(days: (7 - lastOfMonth.weekday) % 7));
    final totalDays = gridEnd.difference(gridStart).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    final rows = <Widget>[];

    // Day-of-week header
    rows.add(Row(
      children: dayNames
          .map((d) => Expanded(
                child: Center(
                  child: Text(d,
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey[500])),
                ),
              ))
          .toList(),
    ));
    rows.add(const SizedBox(height: 4));

    for (int week = 0; week < totalWeeks; week++) {
      final cells = <Widget>[];
      for (int day = 0; day < 7; day++) {
        final date = gridStart.add(Duration(days: week * 7 + day));
        final dateStr = _formatDate(date);
        final isToday = dateStr == _formatDate(now);
        final isFuture = date.isAfter(now);
        final isCurrentMonth = date.month == now.month;

        if (!isCurrentMonth || isFuture) {
          // Outside current month or future: empty cell
          cells.add(Expanded(
              child: _buildHeatmapCell(null, isToday: false)));
        } else {
          final activeRoutines = _activeRoutinesOn(routines, date);

          if (activeRoutines.isEmpty) {
            cells.add(Expanded(
                child: _buildHeatmapCell(null, isToday: isToday)));
          } else {
            final completedCount = activeRoutines
                .where((r) =>
                    widget.completionService.isCompleted(r.id, dateStr))
                .length;
            final skippedCount = activeRoutines
                .where((r) =>
                    widget.completionService.isSkipped(r.id, dateStr))
                .length;
            final rate = completedCount / activeRoutines.length;
            cells.add(Expanded(
              child: _buildHeatmapCell(
                rate,
                isToday: isToday,
                hasSkipped: skippedCount > 0 && completedCount == 0,
              ),
            ));
          }
        }
      }
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: cells),
      ));
    }

    return Column(children: rows);
  }

  Widget _buildHeatmapCell(double? rate,
      {bool isToday = false, bool hasSkipped = false}) {
    Color cellColor;
    if (rate == null) {
      cellColor = Colors.grey.withOpacity(0.08);
    } else if (hasSkipped) {
      cellColor = Colors.orange[200]!;
    } else if (rate >= 1.0) {
      cellColor = Colors.green[400]!;
    } else if (rate >= 0.5) {
      cellColor = Colors.green[200]!;
    } else if (rate > 0) {
      cellColor = Colors.green[100]!;
    } else {
      cellColor = Colors.red[100]!;
    }

    return Container(
      margin: const EdgeInsets.all(1.5),
      height: 28,
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(4),
        border: isToday
            ? Border.all(
                color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
    );
  }

  Widget _buildHeatmapLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.grey.withOpacity(0.15), '없음'),
        const SizedBox(width: 8),
        _buildLegendItem(Colors.red[100]!, '미완'),
        const SizedBox(width: 8),
        _buildLegendItem(Colors.orange[200]!, '스킵'),
        const SizedBox(width: 8),
        _buildLegendItem(Colors.green[200]!, '일부'),
        const SizedBox(width: 8),
        _buildLegendItem(Colors.green[400]!, '완료'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  /// Completion rate for a single routine over N days, only counting active days.
  double _calcRoutineRate(model.Routine routine, int days) {
    if (days <= 0) return 0.0;
    final now = DateTime.now();
    int activeCount = 0;
    int completedCount = 0;

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      if (!routine.isActiveOnDate(date)) continue;
      activeCount++;
      final dateStr = _formatDate(date);
      if (widget.completionService.isCompleted(routine.id, dateStr)) {
        completedCount++;
      }
    }
    return activeCount > 0 ? completedCount / activeCount : 0.0;
  }

  // --- 루틴별 카드 (7일 도트 포함) ---

  Widget _buildRoutineCard(model.Routine routine) {
    final rate = _calcRoutineRate(routine, 30);
    final percentage = (rate * 100).round();

    Color barColor;
    if (percentage >= 80) {
      barColor = Colors.green;
    } else if (percentage >= 50) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoutineStatsScreen(
                routineId: routine.id,
                routineName: routine.name,
                logService: widget.distractionLogService,
                routineStartTime: routine.startTime,
                routineEndTime: routine.endTime,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      routine.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: barColor),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 10),
              _buildWeeklyDots(routine),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rate,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  color: barColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyDots(model.Routine routine) {
    final now = DateTime.now();
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    // Start from Monday of the current week
    final monday = now.subtract(Duration(days: now.weekday - 1));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final date = monday.add(Duration(days: i));
        final dateStr = _formatDate(date);
        final isActive = routine.isActiveOnDate(date);

        final isFuture = date.isAfter(now);
        Color dotColor;
        IconData? dotIcon;
        if (isFuture || !isActive) {
          dotColor = Colors.grey.withOpacity(0.15);
        } else if (widget.completionService.isCompleted(routine.id, dateStr)) {
          dotColor = Colors.green;
          dotIcon = Icons.check;
        } else if (widget.completionService.isSkipped(routine.id, dateStr)) {
          dotColor = Colors.orange;
          dotIcon = Icons.close;
        } else {
          dotColor = Colors.red[100]!;
        }

        return Column(
          children: [
            Text(
              dayNames[date.weekday - 1],
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            ),
            const SizedBox(height: 2),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
              child: dotIcon != null
                  ? Icon(dotIcon, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        );
      }),
    );
  }

  // ==================== 딴짓 탭 ====================

  /// Get the list of date strings for the current distraction filter.
  List<String> _getDistractionFilterDates() {
    final now = DateTime.now();
    switch (_distractionFilter) {
      case 0: // 오늘
        return [_formatDate(now)];
      case 1: // 이번 주
        return List.generate(7, (i) =>
            _formatDate(now.subtract(Duration(days: i))));
      default: // 전체
        return []; // empty = no filter
    }
  }

  Widget _buildDistractionTab() {
    final routines = widget.routineService.getAll();
    final filterDates = _getDistractionFilterDates();

    int totalCount = 0;
    Duration totalTime = Duration.zero;
    final appBreakdown = <String, AppDistractionInfo>{};

    for (final routine in routines) {
      if (filterDates.isEmpty) {
        // 전체
        final stats =
            widget.distractionLogService.getRoutineStats(routine.id);
        for (final entry in stats.appBreakdown.entries) {
          if (_isHiddenApp(entry.value.appPackage)) continue;
          totalCount += entry.value.count;
          totalTime += entry.value.totalTime;
          final existing = appBreakdown[entry.key];
          if (existing != null) {
            existing.count += entry.value.count;
            existing.totalTime += entry.value.totalTime;
          } else {
            appBreakdown[entry.key] = AppDistractionInfo(
              appLabel: entry.value.appLabel,
              appPackage: entry.value.appPackage,
              count: entry.value.count,
              totalTime: entry.value.totalTime,
            );
          }
        }
      } else {
        // 날짜 필터 적용
        for (final date in filterDates) {
          final stats = widget.distractionLogService
              .getRoutineStats(routine.id, date: date);
          for (final entry in stats.appBreakdown.entries) {
            if (_isHiddenApp(entry.value.appPackage)) continue;
            totalCount += entry.value.count;
            totalTime += entry.value.totalTime;
            final existing = appBreakdown[entry.key];
            if (existing != null) {
              existing.count += entry.value.count;
              existing.totalTime += entry.value.totalTime;
            } else {
              appBreakdown[entry.key] = AppDistractionInfo(
                appLabel: entry.value.appLabel,
                appPackage: entry.value.appPackage,
                count: entry.value.count,
                totalTime: entry.value.totalTime,
              );
            }
          }
        }
      }
    }

    final filterLabels = ['오늘', '이번 주', '전체'];

    if (totalCount == 0) {
      return Column(
        children: [
          // 필터 칩
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: List.generate(filterLabels.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filterLabels[i]),
                    selected: _distractionFilter == i,
                    onSelected: (selected) {
                      if (selected) setState(() => _distractionFilter = i);
                    },
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events, size: 64, color: Colors.amber[300]),
                  const SizedBox(height: 16),
                  Text(
                    '딴짓 기록이 없어요!',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '이대로 집중 잘 하고 있네요',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final topApps = appBreakdown.values.toList()
      ..sort((a, b) => b.totalTime.compareTo(a.totalTime));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 필터 칩
        Row(
          children: List.generate(filterLabels.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filterLabels[i]),
                selected: _distractionFilter == i,
                onSelected: (selected) {
                  if (selected) setState(() => _distractionFilter = i);
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        // 요약 카드
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.warning_amber_rounded,
                label: '총 횟수',
                value: '$totalCount회',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.timer_outlined,
                label: '총 시간',
                value: _formatDuration(totalTime),
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 앱별 비중
        if (topApps.isNotEmpty) ...[
          const Text(
            '앱별 딴짓 시간',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...topApps
              .map((app) => _buildAppDistractionCard(app, totalTime)),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDistractionCard(
      AppDistractionInfo app, Duration totalTime) {
    final percentage = totalTime.inSeconds > 0
        ? (app.totalTime.inSeconds / totalTime.inSeconds * 100).round()
        : 0;
    final color = _getAppColor(app.appLabel);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.15),
              child: Text(
                app.appLabel.isNotEmpty ? app.appLabel[0] : '?',
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.appLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalTime.inSeconds > 0
                          ? app.totalTime.inSeconds / totalTime.inSeconds
                          : 0,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$percentage%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  '${app.count}회',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 공통 헬퍼 ====================

  Color _getAppColor(String label) {
    final hash = label.hashCode;
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}시간 ${d.inMinutes.remainder(60)}분';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}분 ${d.inSeconds.remainder(60)}초';
    } else {
      return '${d.inSeconds}초';
    }
  }

  // ==================== 건강 탭 ====================

  Future<void> _loadHealthData() async {
    final hs = widget.healthService;
    if (hs == null) return;

    setState(() => _healthLoading = true);

    try {
      if (!hs.isAuthorized) {
        final granted = await hs.requestAuthorization();
        if (!granted) {
          setState(() {
            _healthLoading = false;
            _healthLoaded = true;
          });
          return;
        }
      }

      final steps = await hs.getTodaySteps();
      final weekly = await hs.getWeeklySteps();
      final sleep = await hs.getLastSleep();
      final hr = await hs.getLatestHeartRate();
      final hrRange = await hs.getTodayHeartRateRange();

      if (mounted) {
        setState(() {
          _todaySteps = steps;
          _weeklySteps = weekly;
          _sleepData = sleep;
          _heartRate = hr;
          _heartRateRange = hrRange;
          _healthLoading = false;
          _healthLoaded = true;
        });
      }
    } catch (e) {
      print('[StatsScreen] _loadHealthData error: $e');
      if (mounted) setState(() => _healthLoading = false);
    }
  }

  Widget _buildHealthTab() {
    final hs = widget.healthService;

    if (hs == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.health_and_safety, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '건강 데이터를 사용할 수 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (!_healthLoaded && !_healthLoading) {
      Future.microtask(() => _loadHealthData());
    }

    if (_healthLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_healthLoaded && !hs.isAuthorized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.health_and_safety_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Health Connect 연결이 필요합니다',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '삼성헬스 데이터를 보려면\nHealth Connect 권한을 허용해주세요',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  setState(() {
                    _healthLoaded = false;
                    _healthLoading = false;
                  });
                },
                icon: const Icon(Icons.link),
                label: const Text('권한 요청'),
              ),
            ],
          ),
        ),
      );
    }

    final hasAnyData = _todaySteps > 0 || _sleepData != null || _heartRate != null;

    if (!hasAnyData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sensors_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                '건강 데이터가 없습니다',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                '삼성헬스에서 Health Connect 동기화를\n켜고 데이터가 쌓이면 여기에 표시됩니다',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _healthLoaded = false;
                    _healthLoading = false;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('새로고침'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Steps today
        _buildStepsCard(),
        const SizedBox(height: 12),

        // Weekly steps bar chart
        if (_weeklySteps.isNotEmpty) ...[
          _buildWeeklyStepsChart(),
          const SizedBox(height: 12),
        ],

        // Sleep
        if (_sleepData != null) ...[
          _buildSleepCard(_sleepData!),
          const SizedBox(height: 12),
        ],

        // Heart rate
        if (_heartRate != null || _heartRateRange != null) ...[
          _buildHeartRateCard(),
          const SizedBox(height: 12),
        ],

        // Refresh
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _healthLoaded = false;
                _healthLoading = false;
              });
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('새로고침'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStepsCard() {
    const goal = 10000;
    final pct = (_todaySteps / goal).clamp(0.0, 1.0);
    final pctInt = (pct * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                const Text(
                  '오늘의 걸음',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.green.withOpacity(0.12),
                        color: Colors.green,
                      ),
                      Center(
                        child: Text(
                          '$pctInt%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatStepNumber(_todaySteps)}보',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '목표: ${_formatStepNumber(goal)}보',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyStepsChart() {
    const maxBarHeight = 100.0;
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];

    int maxSteps = 0;
    for (final ds in _weeklySteps) {
      if (ds.steps > maxSteps) maxSteps = ds.steps;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '주간 걸음',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: maxBarHeight + 50,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(_weeklySteps.length, (i) {
                  final ds = _weeklySteps[i];
                  final barHeight = maxSteps > 0
                      ? (ds.steps / maxSteps * maxBarHeight)
                      : 0.0;
                  final date = DateTime.parse(ds.date);
                  final dayLabel = dayNames[date.weekday - 1];
                  final isToday = ds.date == _formatDate(DateTime.now());

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (ds.steps > 0)
                            Text(
                              _shortSteps(ds.steps),
                              style: TextStyle(
                                fontSize: 9,
                                color: isToday
                                    ? Colors.green
                                    : Colors.grey[600],
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Container(
                            height: barHeight > 0 ? barHeight : 2,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Colors.green
                                  : Colors.green.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                              border: isToday
                                  ? Border.all(color: Colors.green[700]!, width: 1.5)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dayLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? Colors.green : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepCard(SleepData sleep) {
    final h = sleep.total.inHours;
    final m = sleep.total.inMinutes.remainder(60);

    final bedHour = sleep.bedTime.hour.toString().padLeft(2, '0');
    final bedMin = sleep.bedTime.minute.toString().padLeft(2, '0');
    final wakeHour = sleep.wakeTime.hour.toString().padLeft(2, '0');
    final wakeMin = sleep.wakeTime.minute.toString().padLeft(2, '0');

    final totalMin = sleep.total.inMinutes;
    final deepMin = sleep.deep.inMinutes;
    final remMin = sleep.rem.inMinutes;
    final lightMin = sleep.light.inMinutes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bedtime, color: Colors.indigo, size: 24),
                const SizedBox(width: 8),
                const Text(
                  '수면',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${h}시간 ${m}분',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '취침 $bedHour:$bedMin  ->  기상 $wakeHour:$wakeMin',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (totalMin > 0 && (deepMin > 0 || remMin > 0 || lightMin > 0)) ...[
              const SizedBox(height: 12),
              // Sleep stage bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      if (deepMin > 0)
                        Flexible(
                          flex: deepMin,
                          child: Container(color: Colors.indigo[700]),
                        ),
                      if (remMin > 0)
                        Flexible(
                          flex: remMin,
                          child: Container(color: Colors.blue[400]),
                        ),
                      if (lightMin > 0)
                        Flexible(
                          flex: lightMin,
                          child: Container(color: Colors.lightBlue[200]),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (deepMin > 0)
                    _buildSleepLegend(Colors.indigo[700]!, '깊은', _formatSleepDuration(sleep.deep)),
                  if (remMin > 0)
                    _buildSleepLegend(Colors.blue[400]!, '렘', _formatSleepDuration(sleep.rem)),
                  if (lightMin > 0)
                    _buildSleepLegend(Colors.lightBlue[200]!, '얕은', _formatSleepDuration(sleep.light)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSleepLegend(Color color, String label, String duration) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$label $duration',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                const Text(
                  '심박수',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_heartRate != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_heartRate!.bpm}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'bpm',
                      style: TextStyle(fontSize: 14, color: Colors.red),
                    ),
                  ),
                ],
              ),
            if (_heartRateRange != null) ...[
              const SizedBox(height: 8),
              Text(
                '오늘 범위: ${_heartRateRange!.min}~${_heartRateRange!.max} bpm (평균 ${_heartRateRange!.avg})',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatStepNumber(int n) {
    if (n < 1000) return '$n';
    final str = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _shortSteps(int steps) {
    if (steps >= 10000) return '${(steps / 1000).toStringAsFixed(1)}k';
    if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(1)}k';
    return '$steps';
  }

  String _formatSleepDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  // ==================== 앱 사용 탭 ====================

  Future<void> _loadAppUsageStats() async {
    final service = widget.appDetectionService;
    if (service == null) return;

    final hasPerm = await service.hasPermission();
    if (!hasPerm) {
      setState(() {
        _hasUsagePermission = false;
        _appUsageLoading = false;
        _weeklyDayData = [];
      });
      return;
    }

    setState(() {
      _hasUsagePermission = true;
      _appUsageLoading = true;
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    // Load this week (Mon-Sun)
    final weekData = <_DayUsageData>[];
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dateStr = _formatDate(date);

      if (date.isAfter(today)) {
        weekData.add(_DayUsageData(dateStr: dateStr, dayLabel: dayLabels[i], apps: {}));
        continue;
      }

      final dayStats = await service.getDailyUsageStats(dateStr);
      final apps = <String, _AppTimeEntry>{};
      for (final entry in dayStats) {
        final pkg = entry['appPackage'] as String? ?? '';
        if (_isHiddenApp(pkg)) continue;
        final timeMs = entry['totalTime'] as int? ?? 0;
        final label = entry['appLabel'] as String? ?? pkg;
        apps[pkg] = _AppTimeEntry(label: label, package: pkg, time: Duration(milliseconds: timeMs));
      }

      weekData.add(_DayUsageData(dateStr: dateStr, dayLabel: dayLabels[i], apps: apps));
    }

    // Load previous week total for comparison
    Duration prevTotal = Duration.zero;
    final prevMonday = monday.subtract(const Duration(days: 7));
    for (int i = 0; i < 7; i++) {
      final date = prevMonday.add(Duration(days: i));
      final dateStr = _formatDate(date);
      final dayStats = await service.getDailyUsageStats(dateStr);
      for (final entry in dayStats) {
        final pkg = entry['appPackage'] as String? ?? '';
        if (_isHiddenApp(pkg)) continue;
        prevTotal += Duration(milliseconds: (entry['totalTime'] as int? ?? 0));
      }
    }

    setState(() {
      _weeklyDayData = weekData;
      _prevWeekTotal = prevTotal;
      _appUsageLoading = false;
    });
  }

  Widget _buildAppUsageTab() {
    if (widget.appDetectionService == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '앱 사용 통계를 사용할 수 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_hasUsagePermission == null && !_appUsageLoading) {
      Future.microtask(() => _loadAppUsageStats());
    }

    if (_hasUsagePermission == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                '앱 사용 통계 권한이 필요합니다',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '설정에서 사용 정보 접근 권한을 허용해주세요',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  await widget.appDetectionService!.requestPermission();
                  Future.delayed(const Duration(seconds: 1), () {
                    _loadAppUsageStats();
                  });
                },
                icon: const Icon(Icons.settings),
                label: const Text('권한 설정하기'),
              ),
            ],
          ),
        ),
      );
    }

    if (_appUsageLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Compute weekly app totals
    final weeklyAppTotals = <String, _AppTimeEntry>{};
    for (final day in _weeklyDayData) {
      for (final entry in day.apps.entries) {
        final existing = weeklyAppTotals[entry.key];
        if (existing != null) {
          weeklyAppTotals[entry.key] = _AppTimeEntry(
            label: entry.value.label,
            package: entry.value.package,
            time: existing.time + entry.value.time,
          );
        } else {
          weeklyAppTotals[entry.key] = _AppTimeEntry(
            label: entry.value.label,
            package: entry.value.package,
            time: entry.value.time,
          );
        }
      }
    }

    final topApps = weeklyAppTotals.values.toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    final weekTotal = _weeklyDayData.fold<Duration>(
      Duration.zero, (sum, d) => sum + d.totalTime);

    // Determine display data
    Duration displayTotal;
    List<_AppTimeEntry> displayApps;
    if (_selectedDayIndex != null) {
      final day = _weeklyDayData[_selectedDayIndex!];
      displayTotal = day.totalTime;
      displayApps = day.apps.values.toList();
    } else {
      displayTotal = weekTotal;
      displayApps = List.of(topApps);
    }

    if (_selectedAppFilter != null) {
      displayApps = displayApps
          .where((a) => a.package == _selectedAppFilter)
          .toList();
    }
    displayApps.sort((a, b) => b.time.compareTo(a.time));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Week summary card
        _buildWeekSummaryCard(weekTotal),
        const SizedBox(height: 16),

        // Weekly bar chart
        _buildWeeklyBarChart(topApps),
        const SizedBox(height: 12),

        // App filter legend
        if (topApps.isNotEmpty) ...[
          _buildAppFilterLegend(topApps.take(6).toList()),
          const SizedBox(height: 16),
        ],

        // Section header
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedDayIndex != null
                    ? _formatDateWithDay(
                        _weeklyDayData[_selectedDayIndex!].dateStr)
                    : '주간 앱 사용',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (_selectedDayIndex != null)
              TextButton(
                onPressed: () => setState(() => _selectedDayIndex = null),
                child: const Text('주간 전체'),
              ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadAppUsageStats,
              tooltip: '새로고침',
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (displayApps.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                '사용 기록이 없습니다',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else
          ...displayApps
              .map((app) => _buildAppUsageEntry(app, displayTotal)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWeekSummaryCard(Duration weekTotal) {
    final diff = weekTotal - _prevWeekTotal;
    final isIncrease = diff.inSeconds > 0;
    final isDecrease = diff.inSeconds < 0;
    final absDiff = diff.abs();

    final prevSec = _prevWeekTotal.inSeconds;
    final changePercent =
        prevSec > 0 ? (diff.inSeconds / prevSec * 100).round().abs() : 0;

    final daysWithData =
        _weeklyDayData.where((d) => d.totalTime.inSeconds > 0).length;
    final avgPerDay = daysWithData > 0
        ? Duration(milliseconds: weekTotal.inMilliseconds ~/ daysWithData)
        : Duration.zero;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_android, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  '이번 주 사용',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _formatDuration(weekTotal),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            if (_prevWeekTotal.inSeconds > 0)
              Row(
                children: [
                  Icon(
                    isIncrease
                        ? Icons.arrow_upward
                        : isDecrease
                            ? Icons.arrow_downward
                            : Icons.remove,
                    size: 14,
                    color: isIncrease ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '전주 대비 ${_formatDuration(absDiff)}'
                    ' ${isIncrease ? "증가" : isDecrease ? "감소" : ""}'
                    '${changePercent > 0 ? " ($changePercent%)" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isIncrease ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              '하루 평균 ${_formatDuration(avgPerDay)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyBarChart(List<_AppTimeEntry> topApps) {
    const barPadding = 4.0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Find max daily total for scaling
    int maxMs = 0;
    for (final day in _weeklyDayData) {
      final ms = _selectedAppFilter != null
          ? (day.apps[_selectedAppFilter]?.time.inMilliseconds ?? 0)
          : day.totalTime.inMilliseconds;
      if (ms > maxMs) maxMs = ms;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        child: SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final day = _weeklyDayData[i];
              final dayMs = _selectedAppFilter != null
                  ? (day.apps[_selectedAppFilter]?.time.inMilliseconds ?? 0)
                  : day.totalTime.inMilliseconds;
              final ratio = maxMs > 0 ? dayMs / maxMs : 0.0;
              final isSelected = _selectedDayIndex == i;
              final isFuture = DateTime.parse(day.dateStr).isAfter(today);

              return Expanded(
                child: GestureDetector(
                  onTap: isFuture
                      ? null
                      : () {
                          setState(() {
                            _selectedDayIndex =
                                _selectedDayIndex == i ? null : i;
                          });
                        },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: barPadding),
                    child: Column(
                      children: [
                        // Time label + Bar (flexible area)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (dayMs > 0)
                                Text(
                                  _shortDuration(Duration(milliseconds: dayMs)),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey[600],
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              if (ratio > 0)
                                Flexible(
                                  child: FractionallySizedBox(
                                    heightFactor: ratio,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: isSelected
                                            ? Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            isSelected ? 2 : 4),
                                        child: _buildStackedBar(
                                            day, topApps, 999),
                                      ),
                                    ),
                                  ),
                                )
                              else if (!isFuture)
                                Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Day label
                        Text(
                          day.dayLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : isFuture
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                          ),
                        ),
                        // Date
                        Text(
                          _shortDate(day.dateStr),
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildStackedBar(
      _DayUsageData day, List<_AppTimeEntry> topApps, double barHeight) {
    if (barHeight <= 0 || day.totalTime.inMilliseconds <= 0) {
      return const SizedBox.shrink();
    }

    // If app filter is active, single color bar
    if (_selectedAppFilter != null) {
      final appEntry = day.apps[_selectedAppFilter];
      return Container(
        width: double.infinity,
        color: appEntry != null
            ? _getAppColor(appEntry.label)
            : Colors.grey[300],
      );
    }

    // Stacked bar: top 5 apps + other
    final dayTotal = day.totalTime.inMilliseconds;
    final segments = <_BarSegment>[];
    int topMs = 0;

    for (int j = 0; j < topApps.length && j < 5; j++) {
      final appMs =
          day.apps[topApps[j].package]?.time.inMilliseconds ?? 0;
      if (appMs > 0) {
        segments.add(_BarSegment(
            flex: appMs, color: _getAppColor(topApps[j].label)));
        topMs += appMs;
      }
    }

    final otherMs = dayTotal - topMs;
    if (otherMs > 0) {
      segments
          .add(_BarSegment(flex: otherMs, color: Colors.grey[300]!));
    }

    if (segments.isEmpty) return const SizedBox.shrink();

    return Column(
      children: segments
          .map((s) => Flexible(
                flex: s.flex,
                child:
                    Container(width: double.infinity, color: s.color),
              ))
          .toList(),
    );
  }

  Widget _buildAppFilterLegend(List<_AppTimeEntry> topApps) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildFilterChip('전체', null, null),
        ...topApps.map((app) => _buildFilterChip(
              app.label,
              app.package,
              _getAppColor(app.label),
            )),
      ],
    );
  }

  Widget _buildFilterChip(String label, String? package, Color? color) {
    final isSelected = _selectedAppFilter == package;
    final activeColor = color ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAppFilter =
              _selectedAppFilter == package ? null : package;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.15)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppUsageEntry(_AppTimeEntry app, Duration totalDuration) {
    final totalMs = totalDuration.inMilliseconds;
    final appMs = app.time.inMilliseconds;
    final percentage = totalMs > 0 ? (appMs / totalMs * 100).round() : 0;
    final ratio = totalMs > 0 ? appMs / totalMs : 0.0;
    final color = _getAppColor(app.label);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.15),
              child: Text(
                app.label.isNotEmpty ? app.label[0] : '?',
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDuration(app.time),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortDuration(Duration d) {
    if (d.inHours > 0) {
      final mins = d.inMinutes.remainder(60);
      return mins > 0 ? '${d.inHours}h${mins}m' : '${d.inHours}h';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m';
    }
    return '';
  }

  String _shortDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      return '${int.parse(parts[1])}/${int.parse(parts[2])}';
    } catch (_) {
      return '';
    }
  }

  String _formatDateWithDay(String dateStr) {
    try {
      final parts = dateStr.split('-');
      final date = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const dayNames = ['월', '화', '수', '목', '금', '토', '일'];
      return '${int.parse(parts[1])}월 ${int.parse(parts[2])}일'
          ' (${dayNames[date.weekday - 1]})';
    } catch (_) {
      return dateStr;
    }
  }
}

// --- Helper data classes for weekly bar chart ---

class _DayUsageData {
  final String dateStr;
  final String dayLabel;
  final Map<String, _AppTimeEntry> apps;

  _DayUsageData({
    required this.dateStr,
    required this.dayLabel,
    required this.apps,
  });

  Duration get totalTime =>
      apps.values.fold(Duration.zero, (sum, e) => sum + e.time);
}

class _AppTimeEntry {
  final String label;
  final String package;
  final Duration time;

  _AppTimeEntry({
    required this.label,
    required this.package,
    required this.time,
  });
}

class _BarSegment {
  final int flex;
  final Color color;

  _BarSegment({required this.flex, required this.color});
}
