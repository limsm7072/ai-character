import 'package:flutter/material.dart';
import '../models/routine.dart' as model;
import '../models/distraction_log.dart';
import '../services/distraction_log_service.dart';
import '../service_locator.dart';
import '../theme/app_colors.dart';

class RoutineStatsScreen extends StatefulWidget {
  final String routineId;
  final String routineName;
  final model.TimeOfDay? routineStartTime;
  final model.TimeOfDay? routineEndTime;

  const RoutineStatsScreen({
    super.key,
    required this.routineId,
    required this.routineName,
    this.routineStartTime,
    this.routineEndTime,
  });

  @override
  State<RoutineStatsScreen> createState() => _RoutineStatsScreenState();
}

class _RoutineStatsScreenState extends State<RoutineStatsScreen> {
  String _selectedDate = '';
  late Map<String, RoutineStats> _statsByDate;
  late RoutineStats _totalStats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    _statsByDate = getIt<DistractionLogService>().getRoutineStatsByDate(widget.routineId);
    _totalStats = getIt<DistractionLogService>().getRoutineStats(widget.routineId);

    // Sort dates descending
    final dates = _statsByDate.keys.toList()..sort((a, b) => b.compareTo(a));
    _selectedDate = dates.isNotEmpty ? dates.first : '';
  }

  @override
  Widget build(BuildContext context) {
    final dates = _statsByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.routineName} 통계'),
        actions: [
          if (_totalStats.totalDistractions > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmClear,
              tooltip: '기록 삭제',
            ),
        ],
      ),
      body: _totalStats.totalDistractions == 0
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events, size: 64, color: AppColors.trophy),
                  const SizedBox(height: 16),
                  Text(
                    '딴짓 기록이 없어요!',
                    style: TextStyle(fontSize: 18, color: AppColors.grey600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '이대로 집중 잘 하고 있네요',
                    style: TextStyle(color: AppColors.grey500),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total summary card
                _buildTotalSummaryCard(),
                const SizedBox(height: 16),

                // Date selector
                if (dates.length > 1) ...[
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: dates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final date = dates[i];
                        final isSelected = date == _selectedDate;
                        return ChoiceChip(
                          label: Text(_formatDateShort(date)),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedDate = date),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Daily stats
                if (_selectedDate.isNotEmpty &&
                    _statsByDate.containsKey(_selectedDate))
                  _buildDailyStats(_statsByDate[_selectedDate]!),
              ],
            ),
    );
  }

  Widget _buildTotalSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  '전체 요약',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    icon: Icons.warning_amber,
                    label: '총 딴짓 횟수',
                    value: '${_totalStats.totalDistractions}회',
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    icon: Icons.timer,
                    label: '총 딴짓 시간',
                    value: _formatDuration(_totalStats.totalTime),
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    icon: Icons.calendar_today,
                    label: '기록된 일수',
                    value: '${_statsByDate.length}일',
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    icon: Icons.apps,
                    label: '사용한 앱 수',
                    value: '${_totalStats.appBreakdown.length}개',
                    color: AppColors.calendarLunar,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox({
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.grey600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyStats(RoutineStats stats) {
    // Sort apps by total time descending
    final apps = stats.appBreakdown.values.toList()
      ..sort((a, b) => b.totalTime.compareTo(a.totalTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDate(_selectedDate)} 기록',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '딴짓 ${stats.totalDistractions}회 / ${_formatDuration(stats.totalTime)}',
                  style: TextStyle(color: AppColors.grey600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Timeline bar
        if (widget.routineStartTime != null && widget.routineEndTime != null)
          _buildTimelineBar(),

        // App breakdown
        ...apps.map((app) => _buildAppCard(app, stats.totalTime)),
      ],
    );
  }

  Widget _buildTimelineBar() {
    final startTime = widget.routineStartTime!;
    final endTime = widget.routineEndTime!;

    // Parse selected date
    final parts = _selectedDate.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    final routineStartEpoch = DateTime(year, month, day, startTime.hour, startTime.minute).millisecondsSinceEpoch;
    var routineEndEpoch = DateTime(year, month, day, endTime.hour, endTime.minute).millisecondsSinceEpoch;

    // Overnight routine: end is next day
    if (routineEndEpoch <= routineStartEpoch) {
      routineEndEpoch = DateTime(year, month, day + 1, endTime.hour, endTime.minute).millisecondsSinceEpoch;
    }

    final totalMs = routineEndEpoch - routineStartEpoch;
    if (totalMs <= 0) return const SizedBox.shrink();

    // Get individual logs for this date
    final logs = getIt<DistractionLogService>().getByRoutineAndDate(widget.routineId, _selectedDate);
    if (logs.isEmpty) return const SizedBox.shrink();

    // Build timeline blocks
    final blocks = <_TimelineBlock>[];
    for (final log in logs) {
      final left = ((log.startTime - routineStartEpoch) / totalMs).clamp(0.0, 1.0);
      final right = ((log.endTime - routineStartEpoch) / totalMs).clamp(0.0, 1.0);
      if (right > left) {
        blocks.add(_TimelineBlock(
          left: left,
          right: right,
          color: _getAppColor(log.appLabel),
          appLabel: log.appLabel,
          duration: log.duration,
        ));
      }
    }

    // Compute focus stats
    final distractionMs = logs.fold<int>(0, (sum, l) {
      final clampedStart = l.startTime.clamp(routineStartEpoch, routineEndEpoch);
      final clampedEnd = l.endTime.clamp(routineStartEpoch, routineEndEpoch);
      return sum + (clampedEnd - clampedStart);
    });
    final focusMs = totalMs - distractionMs;
    final focusRate = (focusMs / totalMs * 100).round();

    // Build legend: group by app label
    final legendMap = <String, _LegendEntry>{};
    for (final log in logs) {
      final entry = legendMap.putIfAbsent(
        log.appLabel,
        () => _LegendEntry(appLabel: log.appLabel, color: _getAppColor(log.appLabel)),
      );
      entry.totalDuration += log.duration;
    }
    final legendEntries = legendMap.values.toList()
      ..sort((a, b) => b.totalDuration.compareTo(a.totalDuration));

    // Calculate hour markers
    final hourMarkers = <_HourMarker>[];
    // Start from the next full hour after routine start
    final startDateTime = DateTime.fromMillisecondsSinceEpoch(routineStartEpoch);
    final endDateTime = DateTime.fromMillisecondsSinceEpoch(routineEndEpoch);
    var markerTime = DateTime(startDateTime.year, startDateTime.month, startDateTime.day, startDateTime.hour + 1);
    while (markerTime.isBefore(endDateTime)) {
      final pos = (markerTime.millisecondsSinceEpoch - routineStartEpoch) / totalMs;
      if (pos > 0.05 && pos < 0.95) {
        hourMarkers.add(_HourMarker(position: pos, label: '${markerTime.hour}:00'));
      }
      markerTime = markerTime.add(const Duration(hours: 1));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  '시간대별 딴짓',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(startTime.format(), style: TextStyle(fontSize: 11, color: AppColors.grey600)),
                Text(endTime.format(), style: TextStyle(fontSize: 11, color: AppColors.grey600)),
              ],
            ),
            const SizedBox(height: 4),

            // Timeline bar
            SizedBox(
              height: 32,
              child: CustomPaint(
                size: Size.infinite,
                painter: _TimelineBarPainter(
                  blocks: blocks,
                  hourMarkers: hourMarkers,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: legendEntries.map((e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: e.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${e.appLabel} ${_formatDuration(e.totalDuration)}',
                    style: TextStyle(fontSize: 11, color: AppColors.grey700),
                  ),
                ],
              )).toList(),
            ),
            const SizedBox(height: 10),

            // Focus summary
            Row(
              children: [
                Icon(Icons.center_focus_strong, size: 14, color: AppColors.successDark),
                const SizedBox(width: 4),
                Text(
                  '집중 $focusRate% (${_formatDuration(Duration(milliseconds: focusMs))})',
                  style: TextStyle(fontSize: 12, color: AppColors.successDark, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.phone_android, size: 14, color: AppColors.errorMid),
                const SizedBox(width: 4),
                Text(
                  '딴짓 ${_formatDuration(Duration(milliseconds: distractionMs))}',
                  style: TextStyle(fontSize: 12, color: AppColors.errorMid),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppCard(AppDistractionInfo app, Duration totalTime) {
    final percentage = totalTime.inSeconds > 0
        ? (app.totalTime.inSeconds / totalTime.inSeconds * 100).round()
        : 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getAppColor(app.appLabel).withValues(alpha: 0.2),
          child: Text(
            app.appLabel.isNotEmpty ? app.appLabel[0] : '?',
            style: TextStyle(
              color: _getAppColor(app.appLabel),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          app.appLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text('${app.count}회'),
                const SizedBox(width: 12),
                Text(_formatDuration(app.totalTime)),
                const SizedBox(width: 12),
                Text('$percentage%',
                    style: TextStyle(color: AppColors.errorMid)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalTime.inSeconds > 0
                    ? app.totalTime.inSeconds / totalTime.inSeconds
                    : 0,
                minHeight: 6,
                backgroundColor: AppColors.grey200,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getAppColor(String label) {
    final hash = label.hashCode;
    return AppColors.chartColors[hash.abs() % AppColors.chartColors.length];
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

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      return '${int.parse(parts[1])}월 ${int.parse(parts[2])}일';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateShort(String dateStr) {
    try {
      final parts = dateStr.split('-');
      return '${int.parse(parts[1])}/${int.parse(parts[2])}';
    } catch (_) {
      return dateStr;
    }
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('${widget.routineName}의 모든 딴짓 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              await getIt<DistractionLogService>().clearByRoutine(widget.routineId);
              if (mounted) {
                Navigator.pop(context);
                setState(() => _loadStats());
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// --- Helper classes for timeline bar ---

class _TimelineBlock {
  final double left;
  final double right;
  final Color color;
  final String appLabel;
  final Duration duration;

  _TimelineBlock({
    required this.left,
    required this.right,
    required this.color,
    required this.appLabel,
    required this.duration,
  });
}

class _HourMarker {
  final double position;
  final String label;

  _HourMarker({required this.position, required this.label});
}

class _LegendEntry {
  final String appLabel;
  final Color color;
  Duration totalDuration;

  _LegendEntry({required this.appLabel, required this.color, this.totalDuration = Duration.zero});
}

class _TimelineBarPainter extends CustomPainter {
  final List<_TimelineBlock> blocks;
  final List<_HourMarker> hourMarkers;

  _TimelineBarPainter({required this.blocks, required this.hourMarkers});

  @override
  void paint(Canvas canvas, Size size) {
    final barHeight = size.height;
    final barRect = Rect.fromLTWH(0, 0, size.width, barHeight);

    // Background (focus area) - light green
    final bgPaint = Paint()..color = AppColors.successBg;
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(6)),
      bgPaint,
    );

    // Clip to rounded rect
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(6)));

    // Draw distraction blocks
    for (final block in blocks) {
      final blockRect = Rect.fromLTWH(
        block.left * size.width,
        0,
        (block.right - block.left) * size.width,
        barHeight,
      );
      final blockPaint = Paint()..color = block.color.withValues(alpha: 0.85);
      canvas.drawRect(blockRect, blockPaint);
    }

    canvas.restore();

    // Draw hour markers
    final markerPaint = Paint()
      ..color = const Color(0x44000000)
      ..strokeWidth = 1;
    final textStyle = const TextStyle(fontSize: 9, color: Color(0x88000000));

    for (final marker in hourMarkers) {
      final x = marker.position * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, barHeight), markerPaint);

      final textSpan = TextSpan(text: marker.label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, barHeight / 2 - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineBarPainter oldDelegate) => true;
}
