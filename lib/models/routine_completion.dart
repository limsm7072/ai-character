class RoutineCompletion {
  final String routineId;
  final String date; // yyyy-MM-dd
  final int completedAt; // epoch ms
  final String status; // 'completed' or 'skipped'

  RoutineCompletion({
    required this.routineId,
    required this.date,
    required this.completedAt,
    this.status = 'completed',
  });

  bool get isSkipped => status == 'skipped';

  Map<String, dynamic> toJson() => {
        'routineId': routineId,
        'date': date,
        'completedAt': completedAt,
        'status': status,
      };

  factory RoutineCompletion.fromJson(Map<String, dynamic> json) =>
      RoutineCompletion(
        routineId: json['routineId'] ?? '',
        date: json['date'] ?? '',
        completedAt: json['completedAt'] ?? 0,
        status: json['status'] ?? 'completed',
      );
}
