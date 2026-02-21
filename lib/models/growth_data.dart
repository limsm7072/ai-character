import 'dart:math';

class GrowthData {
  final int totalXp;
  final int todayXp;
  final int streak;
  final Map<String, int> xpHistory; // date→xp (최근 30일)

  const GrowthData({
    this.totalXp = 0,
    this.todayXp = 0,
    this.streak = 0,
    this.xpHistory = const {},
  });

  /// 레벨 계산: sqrt(totalXp / 50) + 1
  int get level => (sqrt(totalXp / 50)).floor() + 1;

  /// 현재 레벨까지 필요한 누적 XP
  int get currentLevelXp => (level - 1) * (level - 1) * 50;

  /// 다음 레벨까지 필요한 누적 XP
  int get nextLevelXp => level * level * 50;

  /// 현재 레벨 내 진행도 (0.0 ~ 1.0)
  double get levelProgress {
    final range = nextLevelXp - currentLevelXp;
    if (range <= 0) return 1.0;
    return ((totalXp - currentLevelXp) / range).clamp(0.0, 1.0);
  }

  /// 다음 레벨까지 남은 XP
  int get xpToNextLevel => nextLevelXp - totalXp;

  /// 레벨별 칭호
  String get title {
    if (level >= 15) return '전설의 루티너';
    if (level >= 12) return '습관의 달인';
    if (level >= 10) return '루나의 자랑';
    if (level >= 8) return '꾸준함의 왕';
    if (level >= 6) return '습관 마스터';
    if (level >= 4) return '성장 중';
    if (level >= 2) return '새싹 루티너';
    return '새싹';
  }

  GrowthData copyWith({
    int? totalXp,
    int? todayXp,
    int? streak,
    Map<String, int>? xpHistory,
  }) => GrowthData(
    totalXp: totalXp ?? this.totalXp,
    todayXp: todayXp ?? this.todayXp,
    streak: streak ?? this.streak,
    xpHistory: xpHistory ?? this.xpHistory,
  );

  Map<String, dynamic> toJson() => {
    'totalXp': totalXp,
    'todayXp': todayXp,
    'streak': streak,
    'xpHistory': xpHistory,
  };

  factory GrowthData.fromJson(Map<String, dynamic> json) => GrowthData(
    totalXp: json['totalXp'] as int? ?? 0,
    todayXp: json['todayXp'] as int? ?? 0,
    streak: json['streak'] as int? ?? 0,
    xpHistory: (json['xpHistory'] as Map?)?.map(
      (k, v) => MapEntry(k.toString(), v as int),
    ) ?? {},
  );
}
