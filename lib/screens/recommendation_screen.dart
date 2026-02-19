import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/recommendation_service.dart';
import '../models/recommendation_data.dart';
import '../models/news_article.dart';

class RecommendationScreen extends StatefulWidget {
  final RecommendationService recommendationService;

  const RecommendationScreen({super.key, required this.recommendationService});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');

  RecommendationData? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _data = widget.recommendationService.getCached();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final data = await widget.recommendationService.fetch(force: true);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      print('[RecommendationScreen] fetch error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('링크를 열 수 없습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('맞춤 정보'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _data == null && _loading
            ? const Center(child: CircularProgressIndicator())
            : _data == null || (_data!.tips.isEmpty && _data!.articles.isEmpty)
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.lightbulb_outline, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              '명함을 등록하면 더 정확한\n맞춤 정보를 받을 수 있어요',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (_data!.keywords.isNotEmpty) ...[
                        _buildKeywordsSection(theme),
                        const SizedBox(height: 20),
                      ],
                      if (_data!.tips.isNotEmpty) ...[
                        _buildSectionTitle(theme, Icons.lightbulb_outline, '맞춤 조언'),
                        const SizedBox(height: 10),
                        ..._data!.tips.map((tip) => _buildTipCard(tip, theme)),
                        const SizedBox(height: 20),
                      ],
                      if (_data!.articles.isNotEmpty) ...[
                        _buildSectionTitle(theme, Icons.article_outlined, '관련 뉴스'),
                        const SizedBox(height: 10),
                        ..._data!.articles.map((a) => _buildArticleItem(a, theme)),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _buildKeywordsSection(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _data!.keywords.map((kw) => Chip(
        label: Text(kw, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        visualDensity: VisualDensity.compact,
      )).toList(),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
      ],
    );
  }

  Widget _buildTipCard(RecommendationTip tip, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _categoryColor(tip.category).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_tipIcon(tip.iconName), size: 18, color: _categoryColor(tip.category)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(tip.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _categoryColor(tip.category).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tip.category.label,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _categoryColor(tip.category)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip.message,
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleItem(NewsArticle article, ThemeData theme) {
    return InkWell(
      onTap: () => _openUrl(article.link),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (article.source.isNotEmpty) ...[
                  Text(article.source, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
                  if (article.timeAgo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('·', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4))),
                    ),
                ],
                if (article.timeAgo.isNotEmpty)
                  Text(article.timeAgo, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                const Spacer(),
                Icon(Icons.open_in_new, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(TipCategory cat) {
    switch (cat) {
      case TipCategory.health:
        return const Color(0xFFE91E63); // pink
      case TipCategory.weather:
        return const Color(0xFF2196F3); // blue
      case TipCategory.routine:
        return const Color(0xFF009688); // teal
      case TipCategory.todo:
        return const Color(0xFFFF9800); // orange
      case TipCategory.calendar:
        return const Color(0xFF9C27B0); // purple
    }
  }

  IconData _tipIcon(String name) {
    const map = {
      'directions_walk': Icons.directions_walk,
      'emoji_events': Icons.emoji_events,
      'bedtime': Icons.bedtime,
      'nightlight': Icons.nightlight,
      'monitor_heart': Icons.monitor_heart,
      'umbrella': Icons.umbrella,
      'ac_unit': Icons.ac_unit,
      'severe_cold': Icons.severe_cold,
      'local_fire_department': Icons.local_fire_department,
      'wb_sunny': Icons.wb_sunny,
      'calendar_today': Icons.calendar_today,
      'celebration': Icons.celebration,
      'pending_actions': Icons.pending_actions,
      'task_alt': Icons.task_alt,
      'event': Icons.event,
      'alarm_on': Icons.alarm_on,
    };
    return map[name] ?? Icons.info_outline;
  }
}
