import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recommendation_data.dart';
import '../models/news_article.dart';
import 'card_service.dart';
import 'routine_service.dart';
import 'routine_completion_service.dart';
import 'todo_service.dart';
import 'memo_service.dart';
import 'calendar_service.dart';
import 'weather_service.dart';
import 'health_service.dart';

class RecommendationService {
  static const _cacheKey = 'recommendation_cache';
  static const _cacheTimeKey = 'recommendation_cache_time';
  static const _cacheDuration = Duration(hours: 6);

  final SharedPreferences _prefs;
  final CardService _cardService;
  final RoutineService _routineService;
  final RoutineCompletionService _completionService;
  final TodoService _todoService;
  final MemoService _memoService;
  final CalendarService _calendarService;
  final WeatherService _weatherService;
  final HealthService? _healthService;

  RecommendationData? _cached;

  RecommendationService({
    required SharedPreferences prefs,
    required CardService cardService,
    required RoutineService routineService,
    required RoutineCompletionService completionService,
    required TodoService todoService,
    required MemoService memoService,
    required CalendarService calendarService,
    required WeatherService weatherService,
    HealthService? healthService,
  })  : _prefs = prefs,
        _cardService = cardService,
        _routineService = routineService,
        _completionService = completionService,
        _todoService = todoService,
        _memoService = memoService,
        _calendarService = calendarService,
        _weatherService = weatherService,
        _healthService = healthService {
    _loadCache();
  }

  void _loadCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw != null) {
      _cached = RecommendationData.decode(raw);
    }
  }

  RecommendationData? getCached() => _cached;

  Future<RecommendationData> fetch({bool force = false}) async {
    if (!force) {
      final cacheTime = _prefs.getInt(_cacheTimeKey) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - cacheTime;
      if (elapsed < _cacheDuration.inMilliseconds && _cached != null) {
        return _cached!;
      }
    }

    final keywords = _extractKeywords();
    final tips = await _generateLocalTips();
    final articles = await _fetchKeywordNews(keywords);

    final data = RecommendationData(
      tips: tips,
      articles: articles,
      keywords: keywords,
      fetchedAt: DateTime.now(),
    );

    _cached = data;
    await _prefs.setString(_cacheKey, RecommendationData.encode(data));
    await _prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

    return data;
  }

  // ─── 키워드 추출 ────────────────────────────────

  static const _stopWords = {
    '그리고', '하지만', '그래서', '또는', '및', '등', '위해', '통해',
    '대한', '에서', '으로', '에게', '까지', '부터', '처럼', '보다',
    '것이', '하는', '있는', '없는', '되는', '되어', '이다', '한다',
    '오늘', '내일', '어제', '매일', '매주', '항상', '아침', '저녁',
    '완료', '시작', '종료', '확인', '준비', '정리', '할일', '메모',
    'the', 'and', 'for', 'with', 'from', 'this', 'that', 'todo',
  };

  List<String> _extractKeywords() {
    final words = <String, int>{};

    // 명함: company, position, city, province (개인정보 제외)
    final card = _cardService.get();
    if (card != null && !card.isEmpty) {
      _addWords(words, card.company);
      _addWords(words, card.position);
      _addWords(words, card.city);
      _addWords(words, card.province);
      if (card.interest1.isNotEmpty) _addWords(words, card.interest1);
      if (card.interest2.isNotEmpty) _addWords(words, card.interest2);
      if (card.interest3.isNotEmpty) _addWords(words, card.interest3);
    }

    // 루틴: name, description
    for (final r in _routineService.getAll()) {
      _addWords(words, r.name);
      if (r.description.isNotEmpty) _addWords(words, r.description);
    }

    // 할일: 미완료 todo title
    for (final t in _todoService.getIncomplete()) {
      _addWords(words, t.title);
    }

    // 메모: 최근 5개 title
    final memos = _memoService.getAll();
    for (final m in memos.take(5)) {
      _addWords(words, m.title);
    }

    // 캘린더: 다가오는 5개 이벤트 title
    for (final e in _calendarService.getUpcoming(limit: 5)) {
      _addWords(words, e.title);
    }

    // 불용어 필터 + 정렬 + 최대 5개
    words.removeWhere((k, _) => _stopWords.contains(k.toLowerCase()));
    final sorted = words.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
  }

  void _addWords(Map<String, int> map, String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\w가-힣\s]'), ' ');
    for (final w in cleaned.split(RegExp(r'\s+'))) {
      if (w.length < 2) continue;
      map[w] = (map[w] ?? 0) + 1;
    }
  }

  // ─── 로컬 팁 생성 ──────────────────────────────

  Future<List<RecommendationTip>> _generateLocalTips() async {
    final tips = <RecommendationTip>[];
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 건강 팁
    if (_healthService != null && _healthService.isAuthorized) {
      try {
        final steps = await _healthService.getTodaySteps();
        if (steps > 0 && steps < 5000) {
          tips.add(RecommendationTip(
            iconName: 'directions_walk',
            title: '걸음수 부족',
            message: '오늘 ${_formatNum(steps)}보 걸었어요. 목표 10,000보까지 ${_formatNum(10000 - steps)}보 남았습니다.',
            category: TipCategory.health,
          ));
        } else if (steps >= 10000) {
          tips.add(const RecommendationTip(
            iconName: 'emoji_events',
            title: '걸음수 목표 달성!',
            message: '오늘 10,000보 목표를 달성했어요. 대단해요!',
            category: TipCategory.health,
          ));
        }

        final sleep = await _healthService.getLastSleep();
        if (sleep != null) {
          if (sleep.total.inHours < 6) {
            tips.add(RecommendationTip(
              iconName: 'bedtime',
              title: '수면 부족',
              message: '어젯밤 ${sleep.total.inHours}시간 ${sleep.total.inMinutes.remainder(60)}분 잤어요. 오늘은 일찍 쉬세요.',
              category: TipCategory.health,
            ));
          } else if (sleep.total.inHours >= 7) {
            tips.add(RecommendationTip(
              iconName: 'nightlight',
              title: '충분한 수면',
              message: '어젯밤 ${sleep.total.inHours}시간 ${sleep.total.inMinutes.remainder(60)}분 푹 잤어요. 좋은 컨디션!',
              category: TipCategory.health,
            ));
          }
        }

        final hr = await _healthService.getLatestHeartRate();
        if (hr != null && hr.bpm > 100) {
          tips.add(RecommendationTip(
            iconName: 'monitor_heart',
            title: '심박수 높음',
            message: '현재 심박수 ${hr.bpm}bpm으로 평소보다 높아요. 잠시 휴식을 취해보세요.',
            category: TipCategory.health,
          ));
        }
      } catch (_) {}
    }

    // 날씨 팁
    final weather = _weatherService.getCached();
    if (weather != null) {
      final code = weather.weatherCode;
      if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
        tips.add(const RecommendationTip(
          iconName: 'umbrella',
          title: '비 소식',
          message: '비가 오고 있어요. 우산을 챙기세요!',
          category: TipCategory.weather,
        ));
      } else if (code >= 71 && code <= 77 || code >= 85 && code <= 86) {
        tips.add(const RecommendationTip(
          iconName: 'ac_unit',
          title: '눈 소식',
          message: '눈이 내리고 있어요. 외출 시 미끄럼에 주의하세요.',
          category: TipCategory.weather,
        ));
      }

      if (weather.temperature <= -10) {
        tips.add(RecommendationTip(
          iconName: 'severe_cold',
          title: '한파 주의',
          message: '현재 기온 ${weather.temperature.round()}°C로 매우 춥습니다. 따뜻하게 입으세요.',
          category: TipCategory.weather,
        ));
      } else if (weather.temperature >= 33) {
        tips.add(RecommendationTip(
          iconName: 'local_fire_department',
          title: '폭염 주의',
          message: '현재 기온 ${weather.temperature.round()}°C로 매우 덥습니다. 수분 섭취에 신경 쓰세요.',
          category: TipCategory.weather,
        ));
      }

      if (weather.uvIndex >= 8) {
        tips.add(RecommendationTip(
          iconName: 'wb_sunny',
          title: 'UV 지수 높음',
          message: 'UV 지수 ${weather.uvIndex.round()}으로 높아요. 자외선 차단제를 바르세요.',
          category: TipCategory.weather,
        ));
      }

      // 내일 예보
      if (weather.daily.length > 1) {
        final tomorrow = weather.daily[1];
        tips.add(RecommendationTip(
          iconName: 'calendar_today',
          title: '내일 날씨',
          message: '내일은 ${tomorrow.description}, 최저 ${tomorrow.minTemp.round()}° / 최고 ${tomorrow.maxTemp.round()}° 예상됩니다.',
          category: TipCategory.weather,
        ));
      }
    }

    // 루틴 팁
    final routines = _routineService.getAll();
    final active = routines.where((r) => r.isActiveOnDate(now)).toList();
    if (active.isNotEmpty) {
      final doneCount = active.where((r) =>
          _completionService.isCompleted(r.id, todayStr) ||
          _completionService.isSkipped(r.id, todayStr)).length;
      final total = active.length;
      final rate = total > 0 ? doneCount / total : 0.0;

      if (doneCount == total && total > 0) {
        tips.add(const RecommendationTip(
          iconName: 'celebration',
          title: '오늘의 루틴 완료!',
          message: '모든 루틴을 완료했어요. 수고하셨습니다!',
          category: TipCategory.routine,
        ));
      } else if (rate < 0.5 && now.hour >= 18 && total > 0) {
        tips.add(RecommendationTip(
          iconName: 'pending_actions',
          title: '루틴 완료율 낮음',
          message: '오늘 루틴 완료율이 ${(rate * 100).round()}%예요. 남은 ${total - doneCount}개를 마저 해보세요.',
          category: TipCategory.routine,
        ));
      }
    }

    // 할일 팁
    final incompleteTodos = _todoService.getIncomplete();
    if (incompleteTodos.length >= 5) {
      tips.add(RecommendationTip(
        iconName: 'task_alt',
        title: '미완료 할일 ${incompleteTodos.length}개',
        message: '할일이 쌓이고 있어요. 우선순위를 정해서 하나씩 처리해보세요.',
        category: TipCategory.todo,
      ));
    }

    // 일정 팁
    final todayEvents = _calendarService.getByDate(todayStr);
    if (todayEvents.isNotEmpty) {
      tips.add(RecommendationTip(
        iconName: 'event',
        title: '오늘 일정 ${todayEvents.length}건',
        message: todayEvents.length == 1
            ? '"${todayEvents.first.title}" 일정이 있어요.'
            : '"${todayEvents.first.title}" 외 ${todayEvents.length - 1}건의 일정이 있어요.',
        category: TipCategory.calendar,
      ));
    }

    // D-Day 3일 이내
    final ddayEvents = _calendarService.getDDayEvents();
    for (final e in ddayEvents) {
      final d = DateTime.tryParse(e.date);
      if (d == null) continue;
      final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff >= 0 && diff <= 3) {
        tips.add(RecommendationTip(
          iconName: 'alarm_on',
          title: diff == 0 ? 'D-Day 오늘!' : 'D-${diff}일',
          message: '"${e.title}" ${diff == 0 ? "이 오늘이에요!" : "까지 ${diff}일 남았어요."}',
          category: TipCategory.calendar,
        ));
      }
    }

    return tips;
  }

  // ─── RSS 뉴스 검색 ────────────────────────────

  Future<List<NewsArticle>> _fetchKeywordNews(List<String> keywords) async {
    if (keywords.isEmpty) return [];

    final allArticles = <NewsArticle>[];
    final seenTitles = <String>{};

    for (final keyword in keywords) {
      try {
        final encoded = Uri.encodeComponent(keyword);
        final url = 'https://news.google.com/rss/search?q=$encoded&hl=ko&gl=KR&ceid=KR:ko';
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10);
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('User-Agent', 'Mozilla/5.0');
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        client.close(force: false);

        final articles = _parseRss(body);
        int added = 0;
        for (final a in articles) {
          if (added >= 2) break;
          if (seenTitles.contains(a.title)) continue;
          seenTitles.add(a.title);
          allArticles.add(a);
          added++;
        }
      } catch (e) {
        print('[RecommendationService] keyword news error ($keyword): $e');
      }
    }

    return allArticles.take(10).toList();
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

      final titleMatch = titleRegex.firstMatch(itemXml);
      if (titleMatch == null) continue;
      var title = _cleanXml(titleMatch.group(1)!);
      final dashIdx = title.lastIndexOf(' - ');
      if (dashIdx > 0) title = title.substring(0, dashIdx).trim();
      if (title.isEmpty) continue;

      final linkMatch = linkRegex.firstMatch(itemXml);
      final link = linkMatch != null ? _cleanXml(linkMatch.group(1)!) : '';

      final sourceMatch = sourceRegex.firstMatch(itemXml);
      final source = sourceMatch != null ? _cleanXml(sourceMatch.group(1)!) : '';

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

  String _formatNum(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
