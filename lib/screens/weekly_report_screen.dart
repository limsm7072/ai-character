import 'dart:math';
import 'package:flutter/material.dart';
import '../models/weekly_report_data.dart';
import '../services/weekly_report_service.dart';
import '../service_locator.dart';
import '../theme/app_colors.dart';

class WeeklyReportScreen extends StatefulWidget {
  final String? title;

  const WeeklyReportScreen({super.key, this.title});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final WeeklyReportService _service = getIt<WeeklyReportService>();
  WeeklyReportData? _report;
  bool _loading = true;
  int _weeksAgo = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final report = await _service.generateReport(weeksAgo: _weeksAgo);
      if (mounted) setState(() { _report = report; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeWeek(int delta) {
    final newWeek = _weeksAgo + delta;
    if (newWeek < 0 || newWeek > 8) return;
    _weeksAgo = newWeek;
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '주간 리포트'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? const Center(child: Text('데이터를 불러올 수 없습니다'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 주간 네비게이션
                      _buildWeekNav(theme),
                      const SizedBox(height: 20),

                      // 종합 점수
                      _buildOverallScore(theme),
                      const SizedBox(height: 20),

                      // 요일별 바 차트
                      _buildDailyChart(theme),
                      const SizedBox(height: 20),

                      // 루틴별 성적표
                      _buildRoutineTable(theme),
                      const SizedBox(height: 20),

                      // 딴짓 분석
                      _buildDistractionCard(theme),
                      const SizedBox(height: 20),

                      // XP 획득
                      _buildXpCard(theme),

                      // 루나 코멘트
                      if (_report!.lunaComment.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildLunaComment(theme),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWeekNav(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _weeksAgo < 8 ? () => _changeWeek(1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(_report!.weekLabel,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: _weeksAgo > 0 ? () => _changeWeek(-1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildOverallScore(ThemeData theme) {
    final rate = _report!.overallCompletionRate;
    final percent = (rate * 100).round();
    final color = _scoreColor(rate);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 100, height: 100,
            child: CustomPaint(
              painter: _CircleProgressPainter(
                progress: rate,
                color: color,
                bgColor: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text('$percent%',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('종합 완료율', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text('${_report!.totalCompletedCount}개 루틴 완료',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildDailyChart(ThemeData theme) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    const keys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('요일별 완료율', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final rate = _report!.dailyRates[keys[i]] ?? 0;
                final color = _scoreColor(rate);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${(rate * 100).round()}',
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: max(rate, 0.05),
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(days[i], style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineTable(ThemeData theme) {
    if (_report!.routineStats.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('루틴별 성적표', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ..._report!.routineStats.map((r) {
            final color = _scoreColor(r.rate);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(r.routineName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text('${r.completedDays}/${r.totalDays}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: r.rate,
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text('${(r.rate * 100).round()}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                        textAlign: TextAlign.end),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDistractionCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('딴짓 분석', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBox(theme, '딴짓 횟수', '${_report!.totalDistractionCount}회'),
              const SizedBox(width: 12),
              _statBox(theme, '딴짓 시간', _formatDuration(_report!.totalDistractionTime)),
            ],
          ),
          if (_report!.mostDistractedApp != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber, size: 14, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Text('가장 많이 사용: ${_report!.mostDistractedApp}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.error)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildXpCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, size: 24, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이번 주 획득 XP', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('+${_report!.xpEarned} XP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLunaComment(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('루나의 한마디', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_report!.lunaComment, style: TextStyle(fontSize: 13, height: 1.5, color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _statBox(ThemeData theme, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double rate) {
    if (rate >= 0.8) return const Color(0xFF4CAF50);
    if (rate >= 0.6) return const Color(0xFF26A69A);
    if (rate >= 0.4) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}시간 ${d.inMinutes % 60}분';
    if (d.inMinutes > 0) return '${d.inMinutes}분';
    return '${d.inSeconds}초';
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 6;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter old) =>
      old.progress != progress || old.color != color;
}
