import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class NewsService {
  static const _cacheKey = 'news_headlines_cache';
  static const _cacheTimeKey = 'news_headlines_time';
  static const _cacheDuration = Duration(minutes: 30);
  static const _rssUrl =
      'https://news.google.com/rss?hl=ko&gl=KR&ceid=KR:ko';

  final SharedPreferences _prefs;
  List<String> _headlines = [];

  NewsService(this._prefs) {
    _loadCache();
  }

  void _loadCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      _headlines = (jsonDecode(raw) as List).cast<String>();
    } catch (_) {}
  }

  List<String> getCached() => _headlines;

  Future<List<String>> fetchHeadlines() async {
    final cacheTime = _prefs.getInt(_cacheTimeKey) ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - cacheTime;
    if (elapsed < _cacheDuration.inMilliseconds && _headlines.isNotEmpty) {
      return _headlines;
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(_rssUrl));
      request.headers.set('User-Agent', 'Mozilla/5.0');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: false);

      final itemRegex = RegExp(r'<item>.*?</item>', dotAll: true);
      final titleRegex = RegExp(r'<title>(.*?)</title>', dotAll: true);

      final headlines = <String>[];
      for (final match in itemRegex.allMatches(body)) {
        final itemXml = match.group(0)!;
        final titleMatch = titleRegex.firstMatch(itemXml);
        if (titleMatch != null) {
          var title = titleMatch.group(1)!;
          title = title
              .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&quot;', '"')
              .replaceAll('&#39;', "'")
              .trim();
          // Remove " - Source" suffix
          final dashIdx = title.lastIndexOf(' - ');
          if (dashIdx > 0) title = title.substring(0, dashIdx).trim();
          if (title.isNotEmpty) headlines.add(title);
        }
      }

      if (headlines.isNotEmpty) {
        _headlines = headlines.take(15).toList();
        await _prefs.setString(_cacheKey, jsonEncode(_headlines));
        await _prefs.setInt(
            _cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      }

      return _headlines;
    } catch (e) {
      print('[NewsService] fetch error: $e');
      return _headlines;
    }
  }
}
