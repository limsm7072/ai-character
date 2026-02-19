class RoutineGroup {
  final String id;
  final List<String> routineIds;

  RoutineGroup({required this.id, required this.routineIds});

  Map<String, dynamic> toJson() => {
        'id': id,
        'routineIds': routineIds,
      };

  factory RoutineGroup.fromJson(Map<String, dynamic> json) => RoutineGroup(
        id: json['id'] as String,
        routineIds: List<String>.from(json['routineIds'] ?? []),
      );
}
