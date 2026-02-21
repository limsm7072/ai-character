import 'package:flutter/material.dart';

enum PsychologyCategory {
  cognitiveBias,
  motivation,
  social,
  wellbeing,
  growth,
}

class PsychologyTip {
  final String id;
  final String title;
  final PsychologyCategory category;
  final String description;
  final String dailyTip;
  final String lunaComment;
  final List<String> relatedKeywords;
  final String date;

  const PsychologyTip({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.dailyTip,
    required this.lunaComment,
    this.relatedKeywords = const [],
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.name,
    'description': description,
    'dailyTip': dailyTip,
    'lunaComment': lunaComment,
    'relatedKeywords': relatedKeywords,
    'date': date,
  };

  factory PsychologyTip.fromJson(Map<String, dynamic> json) => PsychologyTip(
    id: json['id'] as String,
    title: json['title'] as String,
    category: PsychologyCategory.values.firstWhere(
      (e) => e.name == json['category'],
      orElse: () => PsychologyCategory.cognitiveBias,
    ),
    description: json['description'] as String? ?? '',
    dailyTip: json['dailyTip'] as String? ?? '',
    lunaComment: json['lunaComment'] as String? ?? '',
    relatedKeywords: (json['relatedKeywords'] as List?)?.cast<String>() ?? [],
    date: json['date'] as String? ?? '',
  );

  static String categoryKorean(PsychologyCategory cat) {
    switch (cat) {
      case PsychologyCategory.cognitiveBias: return '인지편향';
      case PsychologyCategory.motivation: return '동기/행동';
      case PsychologyCategory.social: return '관계/사회';
      case PsychologyCategory.wellbeing: return '감정/웰빙';
      case PsychologyCategory.growth: return '성장/학습';
    }
  }

  static IconData categoryIcon(PsychologyCategory cat) {
    switch (cat) {
      case PsychologyCategory.cognitiveBias: return Icons.visibility;
      case PsychologyCategory.motivation: return Icons.rocket_launch;
      case PsychologyCategory.social: return Icons.people;
      case PsychologyCategory.wellbeing: return Icons.favorite;
      case PsychologyCategory.growth: return Icons.trending_up;
    }
  }

  static Color categoryColor(PsychologyCategory cat) {
    switch (cat) {
      case PsychologyCategory.cognitiveBias: return const Color(0xFF5C6BC0);
      case PsychologyCategory.motivation: return const Color(0xFFFF7043);
      case PsychologyCategory.social: return const Color(0xFF26A69A);
      case PsychologyCategory.wellbeing: return const Color(0xFFEC407A);
      case PsychologyCategory.growth: return const Color(0xFFFFA726);
    }
  }
}
