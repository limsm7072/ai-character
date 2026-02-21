class WeeklyReportData {
  final String weekLabel;
  final double overallCompletionRate;
  final Map<String, double> dailyRates; // 'mon'~'sun' → 0.0~1.0
  final int totalCompletedCount;
  final int totalDistractionCount;
  final Duration totalDistractionTime;
  final String? mostDistractedApp;
  final int xpEarned;
  final String lunaComment;
  final List<RoutineWeekStat> routineStats;
  final String startDate; // yyyy-MM-dd (월요일)
  final String endDate;   // yyyy-MM-dd (일요일)

  const WeeklyReportData({
    required this.weekLabel,
    this.overallCompletionRate = 0,
    this.dailyRates = const {},
    this.totalCompletedCount = 0,
    this.totalDistractionCount = 0,
    this.totalDistractionTime = Duration.zero,
    this.mostDistractedApp,
    this.xpEarned = 0,
    this.lunaComment = '',
    this.routineStats = const [],
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toJson() => {
    'weekLabel': weekLabel,
    'overallCompletionRate': overallCompletionRate,
    'dailyRates': dailyRates,
    'totalCompletedCount': totalCompletedCount,
    'totalDistractionCount': totalDistractionCount,
    'totalDistractionTimeMs': totalDistractionTime.inMilliseconds,
    'mostDistractedApp': mostDistractedApp,
    'xpEarned': xpEarned,
    'lunaComment': lunaComment,
    'routineStats': routineStats.map((r) => r.toJson()).toList(),
    'startDate': startDate,
    'endDate': endDate,
  };

  factory WeeklyReportData.fromJson(Map<String, dynamic> json) => WeeklyReportData(
    weekLabel: json['weekLabel'] as String? ?? '',
    overallCompletionRate: (json['overallCompletionRate'] as num?)?.toDouble() ?? 0,
    dailyRates: (json['dailyRates'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
    totalCompletedCount: json['totalCompletedCount'] as int? ?? 0,
    totalDistractionCount: json['totalDistractionCount'] as int? ?? 0,
    totalDistractionTime: Duration(milliseconds: json['totalDistractionTimeMs'] as int? ?? 0),
    mostDistractedApp: json['mostDistractedApp'] as String?,
    xpEarned: json['xpEarned'] as int? ?? 0,
    lunaComment: json['lunaComment'] as String? ?? '',
    routineStats: (json['routineStats'] as List?)?.map((e) => RoutineWeekStat.fromJson(e)).toList() ?? [],
    startDate: json['startDate'] as String? ?? '',
    endDate: json['endDate'] as String? ?? '',
  );
}

class RoutineWeekStat {
  final String routineId;
  final String routineName;
  final int completedDays;
  final int totalDays;
  final double rate;

  const RoutineWeekStat({
    required this.routineId,
    required this.routineName,
    required this.completedDays,
    required this.totalDays,
    required this.rate,
  });

  Map<String, dynamic> toJson() => {
    'routineId': routineId,
    'routineName': routineName,
    'completedDays': completedDays,
    'totalDays': totalDays,
    'rate': rate,
  };

  factory RoutineWeekStat.fromJson(Map<String, dynamic> json) => RoutineWeekStat(
    routineId: json['routineId'] as String? ?? '',
    routineName: json['routineName'] as String? ?? '',
    completedDays: json['completedDays'] as int? ?? 0,
    totalDays: json['totalDays'] as int? ?? 0,
    rate: (json['rate'] as num?)?.toDouble() ?? 0,
  );
}
