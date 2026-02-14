import 'package:flutter/material.dart';
import '../models/distraction_log.dart';
import '../services/distraction_log_service.dart';

class RoutineStatsScreen extends StatefulWidget {
  final String routineId;
  final String routineName;
  final DistractionLogService logService;

  const RoutineStatsScreen({
    super.key,
    required this.routineId,
    required this.routineName,
    required this.logService,
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
    _statsByDate = widget.logService.getRoutineStatsByDate(widget.routineId);
    _totalStats = widget.logService.getRoutineStats(widget.routineId);

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
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    icon: Icons.timer,
                    label: '총 딴짓 시간',
                    value: _formatDuration(_totalStats.totalTime),
                    color: Colors.red,
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
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    icon: Icons.apps,
                    label: '사용한 앱 수',
                    value: '${_totalStats.appBreakdown.length}개',
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
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // App breakdown
        ...apps.map((app) => _buildAppCard(app, stats.totalTime)),
      ],
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
                    style: TextStyle(color: Colors.red[400])),
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
                backgroundColor: Colors.grey[200],
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
              await widget.logService.clearByRoutine(widget.routineId);
              if (mounted) {
                Navigator.pop(context);
                setState(() => _loadStats());
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
