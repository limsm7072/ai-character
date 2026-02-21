import 'package:flutter/material.dart';
import '../models/activity_data.dart';
import '../services/activity_service.dart';
import '../service_locator.dart';

class ActivityScreen extends StatefulWidget {
  final String? title;

  const ActivityScreen({super.key, this.title});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final ActivityService _activityService = getIt<ActivityService>();
  ActivitySummary? _summary;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (_activityService.isEnabled) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _activityService.fetchToday();
    if (mounted) setState(() { _summary = data; _loading = false; });
  }

  Future<void> _toggleService() async {
    if (_activityService.isEnabled) {
      await _activityService.stop();
      setState(() => _summary = null);
    } else {
      final ok = await _activityService.start();
      if (ok) {
        await _load();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('활동 인식 권한이 필요합니다')),
          );
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = _activityService.isEnabled;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '활동'),
        actions: [
          Switch(
            value: enabled,
            onChanged: (_) => _toggleService(),
          ),
        ],
      ),
      body: !enabled
          ? _buildOnboarding(theme)
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _summary == null || _summary!.entries.isEmpty
                  ? _buildEmpty(theme)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryCards(theme),
                            const SizedBox(height: 16),
                            _buildTimeline(theme),
                            const SizedBox(height: 16),
                            _buildBreakdown(theme),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildOnboarding(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_walk, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('활동 자동 감지', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('걷기, 달리기, 자전거, 차량 이동을\n자동으로 감지하고 기록합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _toggleService,
              icon: const Icon(Icons.play_arrow),
              label: const Text('시작하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('아직 감지된 활동이 없어요', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('기기를 들고 이동하면 자동으로 기록됩니다',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    final s = _summary!;
    final activities = [
      (ActivityType.walking, s.walkingMinutes),
      (ActivityType.running, s.runningMinutes),
      (ActivityType.cycling, s.cyclingMinutes),
      (ActivityType.vehicle, s.vehicleMinutes),
    ].where((e) => e.$2 > 0).toList();

    if (activities.isEmpty && s.stillMinutes > 0) {
      activities.add((ActivityType.still, s.stillMinutes));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘의 활동', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _activityChip(theme, ActivityType.walking, s.walkingMinutes),
              _activityChip(theme, ActivityType.running, s.runningMinutes),
              _activityChip(theme, ActivityType.cycling, s.cyclingMinutes),
              _activityChip(theme, ActivityType.vehicle, s.vehicleMinutes),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityChip(ThemeData theme, ActivityType type, int minutes) {
    final color = ActivitySummary.activityColor(type);
    return Column(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: minutes > 0 ? 0.15 : 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(ActivitySummary.activityIcon(type), size: 24,
              color: minutes > 0 ? color : color.withValues(alpha: 0.3)),
        ),
        const SizedBox(height: 6),
        Text(ActivitySummary.activityKorean(type),
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        Text('${minutes}분',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: minutes > 0 ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildTimeline(ThemeData theme) {
    final segments = _summary!.timeline;
    if (segments.isEmpty) return const SizedBox.shrink();

    // Calculate day range
    final dayStart = DateTime.parse(_summary!.date).millisecondsSinceEpoch;
    final dayEnd = dayStart + 24 * 3600 * 1000;
    final totalMs = dayEnd - dayStart;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('타임라인', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 24,
              child: Stack(
                children: [
                  Container(color: theme.colorScheme.surfaceContainerHighest),
                  ...segments.map((seg) {
                    final left = (seg.startMs - dayStart) / totalMs;
                    final width = (seg.endMs - seg.startMs) / totalMs;
                    return Positioned(
                      left: left * MediaQuery.of(context).size.width * 0.85,
                      width: (width * MediaQuery.of(context).size.width * 0.85).clamp(2.0, double.infinity),
                      top: 0, bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ActivitySummary.activityColor(seg.type),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0시', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
              Text('12시', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
              Text('24시', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: ActivityType.values.where((t) => t != ActivityType.unknown).map((t) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: ActivitySummary.activityColor(t), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text(ActivitySummary.activityKorean(t), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdown(ThemeData theme) {
    final s = _summary!;
    final items = [
      (ActivityType.walking, s.walkingMinutes),
      (ActivityType.running, s.runningMinutes),
      (ActivityType.cycling, s.cyclingMinutes),
      (ActivityType.vehicle, s.vehicleMinutes),
      (ActivityType.still, s.stillMinutes),
    ];

    final totalMin = items.fold<int>(0, (sum, e) => sum + e.$2);
    if (totalMin == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('활동별 비율', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...items.where((e) => e.$2 > 0).map((e) {
            final ratio = e.$2 / totalMin;
            final color = ActivitySummary.activityColor(e.$1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(ActivitySummary.activityIcon(e.$1), size: 16, color: color),
                      const SizedBox(width: 8),
                      Text(ActivitySummary.activityKorean(e.$1),
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
                      const Spacer(),
                      Text('${e.$2}분',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                      const SizedBox(width: 4),
                      Text('${(ratio * 100).round()}%',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
