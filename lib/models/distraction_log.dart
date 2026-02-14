class DistractionLog {
  final String routineId;
  final String routineName;
  final String appPackage;
  final String appLabel;
  final int startTime; // milliseconds since epoch
  final int endTime;
  final String date; // yyyy-MM-dd

  DistractionLog({
    required this.routineId,
    required this.routineName,
    required this.appPackage,
    required this.appLabel,
    required this.startTime,
    required this.endTime,
    required this.date,
  });

  int get durationMs => endTime - startTime;
  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, dynamic> toJson() => {
        'routineId': routineId,
        'routineName': routineName,
        'appPackage': appPackage,
        'appLabel': appLabel,
        'startTime': startTime,
        'endTime': endTime,
        'date': date,
      };

  factory DistractionLog.fromJson(Map<String, dynamic> json) => DistractionLog(
        routineId: json['routineId'] ?? '',
        routineName: json['routineName'] ?? '',
        appPackage: json['appPackage'] ?? '',
        appLabel: json['appLabel'] ?? '',
        startTime: json['startTime'] ?? 0,
        endTime: json['endTime'] ?? 0,
        date: json['date'] ?? '',
      );
}

class RoutineStats {
  final String routineId;
  final String routineName;
  final int totalDistractions;
  final Duration totalTime;
  final Map<String, AppDistractionInfo> appBreakdown;

  RoutineStats({
    required this.routineId,
    required this.routineName,
    required this.totalDistractions,
    required this.totalTime,
    required this.appBreakdown,
  });
}

class AppDistractionInfo {
  final String appLabel;
  final String appPackage;
  int count;
  Duration totalTime;

  AppDistractionInfo({
    required this.appLabel,
    required this.appPackage,
    this.count = 0,
    this.totalTime = Duration.zero,
  });
}
