import 'package:flutter/material.dart';
import '../models/routine.dart' as model;
import '../services/routine_service.dart';
import '../services/routine_completion_service.dart';
import '../services/distraction_log_service.dart';
import '../services/app_detection_service.dart';
import '../models/distraction_log.dart';
import 'routine_stats_screen.dart';

class StatsScreen extends StatefulWidget {
  final RoutineService routineService;
  final RoutineCompletionService completionService;
  final DistractionLogService distractionLogService;
  final AppDetectionService? appDetectionService;

  const StatsScreen({
    super.key,
    required this.routineService,
    required this.completionService,
    required this.distractionLogService,
    this.appDetectionService,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _appUsageWeekly = false;
  bool _appUsageLoading = false;
  List<Map<String, dynamic>> _appUsageData = [];
  bool? _hasUsagePermission;

  // 딴짓 탭 필터: 0=오늘, 1=이번 주, 2=전체
  int _distractionFilter = 0;

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
              tabs: const [
                Tab(text: '완료율'),
                Tab(text: '루틴 중 딴짓'),
                Tab(text: '앱 사용'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _buildCompletionTab(),
            _buildDistractionTab(),
            _buildAppUsageTab(),
          ],
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
        totalCount += stats.totalDistractions;
        totalTime += stats.totalTime;
        for (final entry in stats.appBreakdown.entries) {
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
          totalCount += stats.totalDistractions;
          totalTime += stats.totalTime;
          for (final entry in stats.appBreakdown.entries) {
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

  // ==================== 앱 사용 탭 ====================

  Future<void> _loadAppUsageStats() async {
    final service = widget.appDetectionService;
    if (service == null) return;

    final hasPerm = await service.hasPermission();
    if (!hasPerm) {
      setState(() {
        _hasUsagePermission = false;
        _appUsageLoading = false;
        _appUsageData = [];
      });
      return;
    }

    setState(() {
      _hasUsagePermission = true;
      _appUsageLoading = true;
    });

    final now = DateTime.now();
    final days = _appUsageWeekly ? 7 : 1;
    final Map<String, Map<String, dynamic>> merged = {};

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _formatDate(date);
      final dayStats = await service.getDailyUsageStats(dateStr);
      for (final entry in dayStats) {
        final pkg = entry['appPackage'] as String? ?? '';
        final time = entry['totalTime'] as int? ?? 0;
        final label = entry['appLabel'] as String? ?? pkg;
        if (merged.containsKey(pkg)) {
          merged[pkg]!['totalTime'] = (merged[pkg]!['totalTime'] as int) + time;
        } else {
          merged[pkg] = {
            'appPackage': pkg,
            'appLabel': label,
            'totalTime': time,
          };
        }
      }
    }

    final results = merged.values.toList()
      ..sort((a, b) => (b['totalTime'] as int).compareTo(a['totalTime'] as int));

    setState(() {
      _appUsageData = results;
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

    // Load data on first build or when toggle changes
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
                  // Retry after returning from settings
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

    final totalMs = _appUsageData.fold<int>(
      0, (sum, e) => sum + (e['totalTime'] as int? ?? 0));
    final totalDuration = Duration(milliseconds: totalMs);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 오늘/이번 주 토글
        Row(
          children: [
            ChoiceChip(
              label: const Text('오늘'),
              selected: !_appUsageWeekly,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _appUsageWeekly = false);
                  _loadAppUsageStats();
                }
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('이번 주'),
              selected: _appUsageWeekly,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _appUsageWeekly = true);
                  _loadAppUsageStats();
                }
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadAppUsageStats,
              tooltip: '새로고침',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 총 사용 시간 요약
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.phone_android, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '총 사용 시간',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        _formatDuration(totalDuration),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_appUsageData.length}개 앱',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_appUsageData.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '사용 기록이 없습니다',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else ...[
          Text(
            '앱별 사용 시간',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._appUsageData.map((app) => _buildAppUsageCard(app, totalMs)),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAppUsageCard(Map<String, dynamic> app, int totalMs) {
    final label = app['appLabel'] as String? ?? '';
    final timeMs = app['totalTime'] as int? ?? 0;
    final duration = Duration(milliseconds: timeMs);
    final percentage = totalMs > 0 ? (timeMs / totalMs * 100).round() : 0;
    final ratio = totalMs > 0 ? timeMs / totalMs : 0.0;
    final color = _getAppColor(label);

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
                label.isNotEmpty ? label[0] : '?',
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
                  Text(label,
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
                  _formatDuration(duration),
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
}
