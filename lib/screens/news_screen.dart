import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/news_service.dart';
import '../models/news_article.dart';

class NewsScreen extends StatefulWidget {
  final NewsService newsService;

  const NewsScreen({super.key, required this.newsService});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');

  NewsCategory _category = NewsCategory.top;
  List<NewsArticle> _articles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _articles = widget.newsService.getCachedArticles(_category);
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final list = await widget.newsService.fetchArticles(_category);
    if (mounted) {
      setState(() {
        _articles = list;
        _loading = false;
      });
    }
  }

  void _changeCategory(NewsCategory cat) {
    if (cat == _category) return;
    setState(() {
      _category = cat;
      _articles = widget.newsService.getCachedArticles(cat);
    });
    _fetch();
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
        title: const Text('뉴스'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetch,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryTabs(theme),
          Expanded(
            child: _articles.isEmpty && _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: _articles.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                              Center(
                                child: Text(
                                  '기사가 없습니다',
                                  style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: _articles.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                            itemBuilder: (_, i) => _buildArticleItem(_articles[i], theme),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: NewsCategory.values.map((cat) {
          final selected = cat == _category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat.label),
              selected: selected,
              onSelected: (_) => _changeCategory(cat),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
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
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (article.source.isNotEmpty) ...[
                  Text(
                    article.source,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  ),
                  if (article.timeAgo.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('·', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4))),
                    ),
                  ],
                ],
                if (article.timeAgo.isNotEmpty)
                  Text(
                    article.timeAgo,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  ),
                const Spacer(),
                Icon(Icons.open_in_new, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
