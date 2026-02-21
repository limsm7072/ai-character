enum SuggestionType { timeAdjust, streak, warning, newHabit, improvement }

class RoutineSuggestion {
  final SuggestionType type;
  final String title;
  final String description;
  final String? routineId;
  final DateTime createdAt;

  const RoutineSuggestion({
    required this.type,
    required this.title,
    required this.description,
    this.routineId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    'description': description,
    'routineId': routineId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RoutineSuggestion.fromJson(Map<String, dynamic> json) => RoutineSuggestion(
    type: SuggestionType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => SuggestionType.improvement,
    ),
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    routineId: json['routineId'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  String get icon {
    switch (type) {
      case SuggestionType.timeAdjust: return '⏰';
      case SuggestionType.streak: return '🔥';
      case SuggestionType.warning: return '⚠️';
      case SuggestionType.newHabit: return '✨';
      case SuggestionType.improvement: return '💡';
    }
  }
}
