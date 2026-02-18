import 'dart:convert';

class NewsArticle {
  final String title;
  final String source;
  final String link;
  final DateTime? pubDate;

  const NewsArticle({
    required this.title,
    this.source = '',
    this.link = '',
    this.pubDate,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'source': source,
    'link': link,
    'pubDate': pubDate?.toIso8601String(),
  };

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    title: json['title'] as String? ?? '',
    source: json['source'] as String? ?? '',
    link: json['link'] as String? ?? '',
    pubDate: json['pubDate'] != null ? DateTime.tryParse(json['pubDate'] as String) : null,
  );

  static String encode(List<NewsArticle> articles) =>
      jsonEncode(articles.map((a) => a.toJson()).toList());

  static List<NewsArticle> decode(String raw) {
    try {
      return (jsonDecode(raw) as List)
          .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String get timeAgo {
    if (pubDate == null) return '';
    final diff = DateTime.now().difference(pubDate!);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${pubDate!.month}/${pubDate!.day}';
  }

  /// Parse RFC 2822 date from RSS (e.g. "Thu, 19 Feb 2026 10:00:00 GMT")
  static DateTime? parseRssDate(String raw) {
    try {
      // Remove day name prefix if present
      final cleaned = raw.contains(',') ? raw.substring(raw.indexOf(',') + 1).trim() : raw.trim();
      const months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };
      final parts = cleaned.split(RegExp(r'\s+'));
      if (parts.length < 4) return null;
      final day = int.parse(parts[0]);
      final month = months[parts[1]] ?? 1;
      final year = int.parse(parts[2]);
      final timeParts = parts[3].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;
      return DateTime.utc(year, month, day, hour, minute, second).toLocal();
    } catch (_) {
      return null;
    }
  }
}
