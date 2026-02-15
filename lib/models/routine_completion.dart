class RoutineCompletion {
  final String routineId;
  final String date; // yyyy-MM-dd
  final int completedAt; // epoch ms

  RoutineCompletion({
    required this.routineId,
    required this.date,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'routineId': routineId,
        'date': date,
        'completedAt': completedAt,
      };

  factory RoutineCompletion.fromJson(Map<String, dynamic> json) =>
      RoutineCompletion(
        routineId: json['routineId'] ?? '',
        date: json['date'] ?? '',
        completedAt: json['completedAt'] ?? 0,
      );
}
