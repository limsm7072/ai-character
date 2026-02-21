import 'dart:math';
import 'package:flutter/material.dart';
import '../models/screen_time_data.dart';
import '../services/screen_time_service.dart';
import '../service_locator.dart';
import '../theme/app_colors.dart';

class ScreenTimeScreen extends StatefulWidget {
  final String? title;

  const ScreenTimeScreen({super.key, this.title});

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  final ScreenTimeService _screenTimeService = getIt<ScreenTimeService>();
  ScreenTimeData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _screenTimeService.fetchToday();
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? '스크린타임')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? Center(child: Text('사용 통계 권한이 필요합니다', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _loading = true);
                    await _load();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTotalCard(theme),
                        const SizedBox(height: 16),
                        _buildUnlockCard(theme),
                        const SizedBox(height: 16),
                        _buildCategoryBar(theme),
                        const SizedBox(height: 16),
                        _buildHourlyChart(theme),
                        const SizedBox(height: 16),
                        _buildAppRanking(theme),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildTotalCard(ThemeData theme) {
    final d = _data!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary.withValues(alpha: 0.12), theme.colorScheme.primary.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text('오늘 총 사용시간', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(d.formattedTotalTime,
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
          const SizedBox(height: 4),
          Text('${d.apps.length}개 앱 사용',
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildUnlockCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.lock_open, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('잠금해제', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
              Text('${_data!.unlockCount}회',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(ThemeData theme) {
    final breakdown = _data!.categoryBreakdown;
    if (breakdown.isEmpty) return const SizedBox.shrink();

    final total = _data!.totalTimeMs;
    if (total == 0) return const SizedBox.shrink();

    final colors = <AppCategory, Color>{
      AppCategory.sns: const Color(0xFFE91E63),
      AppCategory.game: const Color(0xFF9C27B0),
      AppCategory.entertainment: const Color(0xFFFF5722),
      AppCategory.productivity: const Color(0xFF2196F3),
      AppCategory.communication: const Color(0xFF4CAF50),
      AppCategory.education: const Color(0xFF00BCD4),
      AppCategory.shopping: const Color(0xFFFF9800),
      AppCategory.finance: const Color(0xFF607D8B),
      AppCategory.health: const Color(0xFF8BC34A),
      AppCategory.other: const Color(0xFF9E9E9E),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('카테고리별', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // Color bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: breakdown.entries.map((e) {
                  final ratio = e.value / total;
                  if (ratio < 0.01) return const SizedBox.shrink();
                  return Expanded(
                    flex: (ratio * 1000).round(),
                    child: Container(color: colors[e.key] ?? Colors.grey),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: breakdown.entries.where((e) => e.value > 0).map((e) {
              final color = colors[e.key] ?? Colors.grey;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text(AppUsageInfo.categoryKorean(e.key), style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  Text(ScreenTimeData.formatDuration(e.value), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(ThemeData theme) {
    final hourly = _data!.hourlyUsageMs;
    final maxVal = hourly.reduce(max);
    if (maxVal == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('시간대별 사용량', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (i) {
                final ratio = hourly[i] / maxVal;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: ratio.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: ratio > 0.5 ? 0.8 : 0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0시', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
              Text('6시', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
              Text('12시', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
              Text('18시', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
              Text('23시', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppRanking(ThemeData theme) {
    final apps = _data!.topApps;
    if (apps.isEmpty) return const SizedBox.shrink();

    final colors = <AppCategory, Color>{
      AppCategory.sns: const Color(0xFFE91E63),
      AppCategory.game: const Color(0xFF9C27B0),
      AppCategory.entertainment: const Color(0xFFFF5722),
      AppCategory.productivity: const Color(0xFF2196F3),
      AppCategory.communication: const Color(0xFF4CAF50),
      AppCategory.education: const Color(0xFF00BCD4),
      AppCategory.shopping: const Color(0xFFFF9800),
      AppCategory.finance: const Color(0xFF607D8B),
      AppCategory.health: const Color(0xFF8BC34A),
      AppCategory.other: const Color(0xFF9E9E9E),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('앱 사용 순위', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...apps.asMap().entries.map((e) {
            final i = e.key;
            final app = e.value;
            final catColor = colors[app.category] ?? Colors.grey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 20,
                    child: Text('${i + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant))),
                  const SizedBox(width: 8),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text(app.appName.isNotEmpty ? app.appName[0] : '?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: catColor))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.appName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        Text(AppUsageInfo.categoryKorean(app.category),
                            style: TextStyle(fontSize: 11, color: catColor)),
                      ],
                    ),
                  ),
                  Text(ScreenTimeData.formatDuration(app.totalTimeMs),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
