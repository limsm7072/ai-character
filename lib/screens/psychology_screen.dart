import 'package:flutter/material.dart';
import '../models/psychology_tip.dart';
import '../services/psychology_service.dart';
import '../service_locator.dart';
import '../theme/app_colors.dart';

class PsychologyScreen extends StatefulWidget {
  final String? title;

  const PsychologyScreen({super.key, this.title});

  @override
  State<PsychologyScreen> createState() => _PsychologyScreenState();
}

class _PsychologyScreenState extends State<PsychologyScreen> {
  final PsychologyService _psychologyService = getIt<PsychologyService>();
  PsychologyTip? _todayTip;
  List<PsychologyTip> _history = [];
  PsychologyCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _todayTip = _psychologyService.generateTodayTip();
    _history = _psychologyService.getHistory();
  }

  List<PsychologyTip> get _filteredHistory {
    if (_filterCategory == null) return _history;
    return _history.where((t) => t.category == _filterCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? '오늘의 심리학')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 오늘의 개념 카드 ───
            if (_todayTip != null) _buildTodayCard(theme),

            const SizedBox(height: 24),

            // ─── 카테고리 필터 ───
            Text('지난 심리학 팁', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip(theme, null, '전체'),
                  ...PsychologyCategory.values.map((cat) =>
                    _filterChip(theme, cat, PsychologyTip.categoryKorean(cat)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── 히스토리 리스트 ───
            if (_filteredHistory.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('아직 기록이 없어요', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ),
              )
            else
              ..._filteredHistory.where((t) => t.date != _todayTip?.date).map((tip) =>
                _buildHistoryItem(theme, tip),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard(ThemeData theme) {
    final tip = _todayTip!;
    final catColor = PsychologyTip.categoryColor(tip.category);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [catColor.withValues(alpha: 0.15), catColor.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: catColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리 칩
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PsychologyTip.categoryIcon(tip.category), size: 14, color: catColor),
                const SizedBox(width: 4),
                Text(PsychologyTip.categoryKorean(tip.category),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: catColor)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 제목
          Text(tip.title,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          // 설명
          Text(tip.description,
            style: TextStyle(fontSize: 14, height: 1.6, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 16),

          // 일상 적용 팁
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text('오늘의 적용 팁', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(tip.dailyTip,
                  style: TextStyle(fontSize: 13, height: 1.5, color: theme.colorScheme.onSurface)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 루나 코멘트
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
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
                Text(tip.lunaComment,
                  style: TextStyle(fontSize: 13, height: 1.5, color: theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(ThemeData theme, PsychologyCategory? category, String label) {
    final selected = _filterCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _filterCategory = category),
        selectedColor: theme.colorScheme.primaryContainer,
        checkmarkColor: theme.colorScheme.primary,
        side: BorderSide(color: selected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildHistoryItem(ThemeData theme, PsychologyTip tip) {
    final catColor = PsychologyTip.categoryColor(tip.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTipDetail(tip),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(PsychologyTip.categoryIcon(tip.category), size: 18, color: catColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(PsychologyTip.categoryKorean(tip.category),
                      style: TextStyle(fontSize: 11, color: catColor)),
                  ],
                ),
              ),
              Text(_formatDate(tip.date),
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  void _showTipDetail(PsychologyTip tip) {
    final theme = Theme.of(context);
    final catColor = PsychologyTip.categoryColor(tip.category);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(PsychologyTip.categoryKorean(tip.category),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: catColor)),
              ),
              const SizedBox(height: 12),
              Text(tip.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(tip.date, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              Text(tip.description, style: TextStyle(fontSize: 14, height: 1.6)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text('적용 팁', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(tip.dailyTip, style: TextStyle(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
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
                    Text(tip.lunaComment, style: TextStyle(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      return '${int.parse(parts[1])}/${int.parse(parts[2])}';
    } catch (_) {
      return dateStr;
    }
  }
}
