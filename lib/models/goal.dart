import 'package:flutter/material.dart';

class Milestone {
  String id;
  String title;
  bool isCompleted;
  int? completedAt;

  Milestone({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    if (completedAt != null) 'completedAt': completedAt,
  };

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
    id: json['id'] as String,
    title: json['title'] as String,
    isCompleted: json['isCompleted'] as bool? ?? false,
    completedAt: json['completedAt'] as int?,
  );
}

class Goal {
  String id;
  String title;
  String description;
  String category;
  String? targetDate; // yyyy-MM-dd
  List<String> linkedRoutineIds;
  List<String> linkedTodoIds;
  List<Milestone> milestones;
  bool isCompleted;
  int createdAt;
  int? completedAt;

  Goal({
    required this.id,
    required this.title,
    this.description = '',
    this.category = '기타',
    this.targetDate,
    List<String>? linkedRoutineIds,
    List<String>? linkedTodoIds,
    List<Milestone>? milestones,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
  })  : linkedRoutineIds = linkedRoutineIds ?? [],
        linkedTodoIds = linkedTodoIds ?? [],
        milestones = milestones ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    if (targetDate != null) 'targetDate': targetDate,
    'linkedRoutineIds': linkedRoutineIds,
    'linkedTodoIds': linkedTodoIds,
    'milestones': milestones.map((m) => m.toJson()).toList(),
    'isCompleted': isCompleted,
    'createdAt': createdAt,
    if (completedAt != null) 'completedAt': completedAt,
  };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? '기타',
    targetDate: json['targetDate'] as String?,
    linkedRoutineIds: (json['linkedRoutineIds'] as List?)?.cast<String>() ?? [],
    linkedTodoIds: (json['linkedTodoIds'] as List?)?.cast<String>() ?? [],
    milestones: (json['milestones'] as List?)
        ?.map((e) => Milestone.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    isCompleted: json['isCompleted'] as bool? ?? false,
    createdAt: json['createdAt'] as int,
    completedAt: json['completedAt'] as int?,
  );

  bool get isOverdue {
    if (targetDate == null || isCompleted) return false;
    final due = DateTime.tryParse(targetDate!);
    if (due == null) return false;
    final today = DateTime.now();
    return DateTime(due.year, due.month, due.day)
        .isBefore(DateTime(today.year, today.month, today.day));
  }

  String? get dDayString {
    if (targetDate == null) return null;
    final due = DateTime.tryParse(targetDate!);
    if (due == null) return null;
    final today = DateTime.now();
    final diff = DateTime(due.year, due.month, due.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff == 0) return 'D-Day';
    if (diff > 0) return 'D-$diff';
    return 'D+${-diff}';
  }

  int get completedMilestones => milestones.where((m) => m.isCompleted).length;

  static const categories = ['건강', '커리어', '학습', '재정', '관계', '기타'];

  static IconData categoryIcon(String cat) {
    switch (cat) {
      case '건강': return Icons.fitness_center;
      case '커리어': return Icons.work_outline;
      case '학습': return Icons.school_outlined;
      case '재정': return Icons.savings_outlined;
      case '관계': return Icons.people_outline;
      default: return Icons.star_outline;
    }
  }

  static Color categoryColor(String cat) {
    switch (cat) {
      case '건강': return const Color(0xFF4CAF50);
      case '커리어': return const Color(0xFF2196F3);
      case '학습': return const Color(0xFFFF9800);
      case '재정': return const Color(0xFF9C27B0);
      case '관계': return const Color(0xFFE91E63);
      default: return const Color(0xFF607D8B);
    }
  }
}
