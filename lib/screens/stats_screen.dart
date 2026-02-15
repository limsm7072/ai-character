import 'package:flutter/material.dart';
import '../models/routine.dart' as model;
import '../services/routine_service.dart';
import '../services/routine_completion_service.dart';
import '../services/distraction_log_service.dart';
import '../models/distraction_log.dart';
import 'routine_stats_screen.dart';

class StatsScreen extends StatefulWidget {
  final RoutineService routineService;
  final RoutineCompletionService completionService;
  final DistractionLogService distractionLogService;

  const StatsScreen({
    super.key,
    required this.routineService,
    required this.completionService,
    required this.distractionLogService,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    final routines = widget.routineService.getAll();
    final today = widget.completionService.todayStr();

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('통계'),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Completion summary card
                _buildCompletionSummaryCard(routines, today),
                const SizedBox(height: 20),

                // Routine completion rates
                _buildSectionHeader('루틴별 완료율 (최근 30일)'),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // Routine completion list
        if (routines.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  '등록된 루틴이 없습니다',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _buildRoutineRateCard(routines[index]),
              childCount: routines.length,
            ),
          ),

        // Distraction stats section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: _buildSectionHeader('딴짓 통계'),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildDistractionSummaryCard(routines),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCompletionSummaryCard(
      List<model.Routine> routines, String today) {
    if (routines.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              '루틴을 추가하면 완료율을 볼 수 있어요',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      );
    }

    // Today's completion rate
    final todayCompleted = routines
        .where((r) => widget.completionService.isCompleted(r.id, today))
        .length;
    final todayRate =
        routines.isNotEmpty ? todayCompleted / routines.length : 0.0;

    // This week (last 7 days)
    double weekRate = 0;
    for (final r in routines) {
      weekRate += widget.completionService.getCompletionRate(r.id, 7);
    }
    weekRate = routines.isNotEmpty ? weekRate / routines.length : 0;

    // This month (last 30 days)
    double monthRate = 0;
    for (final r in routines) {
      monthRate += widget.completionService.getCompletionRate(r.id, 30);
    }
    monthRate = routines.isNotEmpty ? monthRate / routines.length : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  '루틴 완료율',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRateBox(
                    label: '오늘',
                    rate: todayRate,
                    detail: '$todayCompleted/${routines.length}',
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRateBox(
                    label: '이번 주',
                    rate: weekRate,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRateBox(
                    label: '이번 달',
                    rate: monthRate,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateBox({
    required String label,
    required double rate,
    String? detail,
    required Color color,
  }) {
    final percentage = (rate * 100).round();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (detail != null)
            Text(
              detail,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineRateCard(model.Routine routine) {
    final rate =
        widget.completionService.getCompletionRate(routine.id, 30);
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                      fontWeight: FontWeight.bold,
                      color: barColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rate,
                  minHeight: 8,
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

  Widget _buildDistractionSummaryCard(List<model.Routine> routines) {
    // Aggregate distraction stats across all routines
    int totalCount = 0;
    Duration totalTime = Duration.zero;
    final appBreakdown = <String, AppDistractionInfo>{};

    for (final routine in routines) {
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
    }

    if (totalCount == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber[400]),
              const SizedBox(width: 12),
              Text(
                '딴짓 기록이 없어요!',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Sort apps by time descending, take top 5
    final topApps = appBreakdown.values.toList()
      ..sort((a, b) => b.totalTime.compareTo(a.totalTime));
    final displayApps = topApps.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.warning_amber,
                    label: '총 횟수',
                    value: '${totalCount}회',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.timer,
                    label: '총 시간',
                    value: _formatDuration(totalTime),
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            if (displayApps.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '앱별 비중',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...displayApps.map((app) {
                final pct = totalTime.inSeconds > 0
                    ? (app.totalTime.inSeconds / totalTime.inSeconds * 100)
                        .round()
                    : 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            _getAppColor(app.appLabel).withValues(alpha: 0.2),
                        child: Text(
                          app.appLabel.isNotEmpty ? app.appLabel[0] : '?',
                          style: TextStyle(
                            fontSize: 11,
                            color: _getAppColor(app.appLabel),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(app.appLabel, style: const TextStyle(fontSize: 13))),
                      Text('$pct%',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600)),
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

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

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
}
