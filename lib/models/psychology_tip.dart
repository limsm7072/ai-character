import 'package:flutter/material.dart';

enum PsychologyCategory {
  relationship,
  mindset,
  success,
  emotion,
  lifestyle,
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
      orElse: () => PsychologyCategory.mindset,
    ),
    description: json['description'] as String? ?? '',
    dailyTip: json['dailyTip'] as String? ?? '',
    lunaComment: json['lunaComment'] as String? ?? '',
    relatedKeywords: (json['relatedKeywords'] as List?)?.cast<String>() ?? [],
    date: json['date'] as String? ?? '',
  );

  static String categoryKorean(PsychologyCategory cat) {
    switch (cat) {
      case PsychologyCategory.relationship: return '인간관계';
      case PsychologyCategory.mindset: return '마인드셋';
      case PsychologyCategory.success: return '성공/성장';
      case PsychologyCategory.emotion: return '감정/심리';
      case PsychologyCategory.lifestyle: return '라이프스타일';
    }
  }

  static IconData categoryIcon(PsychologyCategory cat) {
    switch (cat) {
      case PsychologyCategory.relationship: return Icons.people;
      case PsychologyCategory.mindset: return Icons.lightbulb;
      case PsychologyCategory.success: return Icons.rocket_launch;
      case PsychologyCategory.emotion: return Icons.favorite;
      case PsychologyCategory.lifestyle: return Icons.auto_awesome;
    }
  }

  static Color categoryColor(PsychologyCategory cat) {
    switch (cat) {
      case PsychologyCategory.relationship: return const Color(0xFF26A69A);
      case PsychologyCategory.mindset: return const Color(0xFF5C6BC0);
      case PsychologyCategory.success: return const Color(0xFFFF7043);
      case PsychologyCategory.emotion: return const Color(0xFFEC407A);
      case PsychologyCategory.lifestyle: return const Color(0xFFFFA726);
    }
  }
}
