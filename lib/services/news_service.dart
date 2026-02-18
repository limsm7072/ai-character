import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_article.dart';

enum NewsCategory {
  top('주요뉴스', 'https://news.google.com/rss?hl=ko&gl=KR&ceid=KR:ko'),
  business('비즈니스', 'https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGRqTVhZU0FtdHZHZ0pMVWlnQVAB?hl=ko&gl=KR&ceid=KR:ko'),
  technology('과학기술', 'https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx6TVdZU0FtdHZHZ0pMVWlnQVAB?hl=ko&gl=KR&ceid=KR:ko'),
  sports('스포츠', 'https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRFp1ZEdvU0FtdHZHZ0pMVWlnQVAB?hl=ko&gl=KR&ceid=KR:ko'),
  entertainment('연예', 'https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNREpxYW5RU0FtdHZHZ0pMVWlnQVAB?hl=ko&gl=KR&ceid=KR:ko');

  final String label;
  final String url;
  const NewsCategory(this.label, this.url);
}

class NewsService {
  static const _cacheKey = 'news_headlines_cache';
  static const _cacheTimeKey = 'news_headlines_time';
  static const _articlesCacheKey = 'news_articles_cache';
  static const _cacheDuration = Duration(minutes: 30);

  final SharedPreferences _prefs;
  List<String> _headlines = [];
  Map<NewsCategory, List<NewsArticle>> _articlesCache = {};

  NewsService(this._prefs) {
    _loadCache();
  }

  void _loadCache() {
    // Legacy headline cache (for ticker)
    final raw = _prefs.getString(_cacheKey);
    if (raw != null) {
      try {
        _headlines = (jsonDecode(raw) as List).cast<String>();
      } catch (_) {}
    }
    // Articles cache
    final artRaw = _prefs.getString(_articlesCacheKey);
    if (artRaw != null) {
      try {
        final map = jsonDecode(artRaw) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final cat = NewsCategory.values.firstWhere(
            (c) => c.name == entry.key,
            orElse: () => NewsCategory.top,
          );
          _articlesCache[cat] = (entry.value as List)
              .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }
  }

  List<String> getCached() => _headlines;

  List<NewsArticle> getCachedArticles([NewsCategory category = NewsCategory.top]) =>
      _articlesCache[category] ?? [];

  Future<List<String>> fetchHeadlines() async {
    final articles = await fetchArticles(NewsCategory.top);
    return articles.map((a) => a.title).toList();
  }

  Future<List<NewsArticle>> fetchArticles([NewsCategory category = NewsCategory.top]) async {
    // Check per-category cache
    final cacheTime = _prefs.getInt('${_cacheTimeKey}_${category.name}') ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - cacheTime;
    if (elapsed < _cacheDuration.inMilliseconds && (_articlesCache[category]?.isNotEmpty ?? false)) {
      return _articlesCache[category]!;
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(category.url));
      request.headers.set('User-Agent', 'Mozilla/5.0');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: false);

      final articles = _parseRss(body);

      if (articles.isNotEmpty) {
        _articlesCache[category] = articles;

        // Update legacy headlines for ticker (top category only)
        if (category == NewsCategory.top) {
          _headlines = articles.map((a) => a.title).toList();
          await _prefs.setString(_cacheKey, jsonEncode(_headlines));
          await _prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
        }

        // Save articles cache
        await _saveArticlesCache();
        await _prefs.setInt('${_cacheTimeKey}_${category.name}', DateTime.now().millisecondsSinceEpoch);
      }

      return _articlesCache[category] ?? [];
    } catch (e) {
      print('[NewsService] fetch error: $e');
      return _articlesCache[category] ?? [];
    }
  }

  List<NewsArticle> _parseRss(String body) {
    final itemRegex = RegExp(r'<item>.*?</item>', dotAll: true);
    final titleRegex = RegExp(r'<title>(.*?)</title>', dotAll: true);
    final linkRegex = RegExp(r'<link>(.*?)</link>', dotAll: true);
    final sourceRegex = RegExp(r'<source[^>]*>(.*?)</source>', dotAll: true);
    final pubDateRegex = RegExp(r'<pubDate>(.*?)</pubDate>', dotAll: true);

    final articles = <NewsArticle>[];
    for (final match in itemRegex.allMatches(body)) {
      final itemXml = match.group(0)!;

      // Title
      final titleMatch = titleRegex.firstMatch(itemXml);
      if (titleMatch == null) continue;
      var title = _cleanXml(titleMatch.group(1)!);
      // Remove " - Source" suffix from title
      final dashIdx = title.lastIndexOf(' - ');
      if (dashIdx > 0) title = title.substring(0, dashIdx).trim();
      if (title.isEmpty) continue;

      // Link
      final linkMatch = linkRegex.firstMatch(itemXml);
      final link = linkMatch != null ? _cleanXml(linkMatch.group(1)!) : '';

      // Source
      final sourceMatch = sourceRegex.firstMatch(itemXml);
      final source = sourceMatch != null ? _cleanXml(sourceMatch.group(1)!) : '';

      // PubDate
      final pubDateMatch = pubDateRegex.firstMatch(itemXml);
      final pubDate = pubDateMatch != null
          ? NewsArticle.parseRssDate(_cleanXml(pubDateMatch.group(1)!))
          : null;

      articles.add(NewsArticle(
        title: title,
        source: source,
        link: link,
        pubDate: pubDate,
      ));
    }

    return articles.take(20).toList();
  }

  String _cleanXml(String raw) => raw
      .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();

  Future<void> _saveArticlesCache() async {
    final map = <String, dynamic>{};
    for (final entry in _articlesCache.entries) {
      map[entry.key.name] = entry.value.map((a) => a.toJson()).toList();
    }
    await _prefs.setString(_articlesCacheKey, jsonEncode(map));
  }
}
