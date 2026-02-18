import 'dart:convert';
import 'news_article.dart';

enum TipCategory {
  health('건강', 'heart'),
  weather('날씨', 'cloud'),
  routine('루틴', 'check'),
  todo('할일', 'list'),
  calendar('일정', 'calendar');

  final String label;
  final String iconName;
  const TipCategory(this.label, this.iconName);
}

class RecommendationTip {
  final String iconName;
  final String title;
  final String message;
  final TipCategory category;

  const RecommendationTip({
    required this.iconName,
    required this.title,
    required this.message,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'iconName': iconName,
    'title': title,
    'message': message,
    'category': category.name,
  };

  factory RecommendationTip.fromJson(Map<String, dynamic> json) =>
      RecommendationTip(
        iconName: json['iconName'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        category: TipCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => TipCategory.health,
        ),
      );
}

class RecommendationData {
  final List<RecommendationTip> tips;
  final List<NewsArticle> articles;
  final List<String> keywords;
  final DateTime fetchedAt;

  const RecommendationData({
    required this.tips,
    required this.articles,
    required this.keywords,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
    'tips': tips.map((t) => t.toJson()).toList(),
    'articles': articles.map((a) => a.toJson()).toList(),
    'keywords': keywords,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory RecommendationData.fromJson(Map<String, dynamic> json) =>
      RecommendationData(
        tips: (json['tips'] as List?)
                ?.map((e) => RecommendationTip.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        articles: (json['articles'] as List?)
                ?.map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        keywords: (json['keywords'] as List?)?.cast<String>() ?? [],
        fetchedAt: json['fetchedAt'] != null
            ? DateTime.tryParse(json['fetchedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  static String encode(RecommendationData data) => jsonEncode(data.toJson());

  static RecommendationData? decode(String raw) {
    try {
      return RecommendationData.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
