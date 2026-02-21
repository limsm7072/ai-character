enum AppCategory {
  sns,
  game,
  entertainment,
  productivity,
  communication,
  education,
  shopping,
  finance,
  health,
  other,
}

class AppUsageInfo {
  final String appName;
  final String packageName;
  final int totalTimeMs;
  final AppCategory category;

  const AppUsageInfo({
    required this.appName,
    required this.packageName,
    required this.totalTimeMs,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'appName': appName,
    'packageName': packageName,
    'totalTimeMs': totalTimeMs,
    'category': category.name,
  };

  factory AppUsageInfo.fromJson(Map<String, dynamic> json) => AppUsageInfo(
    appName: json['appName'] as String? ?? '',
    packageName: json['packageName'] as String? ?? '',
    totalTimeMs: json['totalTimeMs'] as int? ?? 0,
    category: AppCategory.values.firstWhere(
      (e) => e.name == json['category'],
      orElse: () => AppCategory.other,
    ),
  );

  static AppCategory categorize(String packageName) {
    final pkg = packageName.toLowerCase();
    // SNS
    if (pkg.contains('instagram') || pkg.contains('facebook') ||
        pkg.contains('twitter') || pkg.contains('tiktok') ||
        pkg.contains('reddit') || pkg.contains('threads') ||
        pkg.contains('band') || pkg.contains('weibo')) {
      return AppCategory.sns;
    }
    // Entertainment
    if (pkg.contains('youtube') || pkg.contains('netflix') ||
        pkg.contains('spotify') || pkg.contains('twitch') ||
        pkg.contains('watcha') || pkg.contains('wavve') ||
        pkg.contains('tving') || pkg.contains('melon') ||
        pkg.contains('bugs') || pkg.contains('webtoon') ||
        pkg.contains('comic')) {
      return AppCategory.entertainment;
    }
    // Communication
    if (pkg.contains('kakao') || pkg.contains('whatsapp') ||
        pkg.contains('telegram') || pkg.contains('discord') ||
        pkg.contains('line') || pkg.contains('signal') ||
        pkg.contains('messenger')) {
      return AppCategory.communication;
    }
    // Shopping
    if (pkg.contains('coupang') || pkg.contains('baemin') ||
        pkg.contains('danggeun') || pkg.contains('daangn') ||
        pkg.contains('gmarket') || pkg.contains('11st') ||
        pkg.contains('auction') || pkg.contains('ssg') ||
        pkg.contains('kurly')) {
      return AppCategory.shopping;
    }
    // Finance
    if (pkg.contains('toss') || pkg.contains('banking') ||
        pkg.contains('kbstar') || pkg.contains('shinhan') ||
        pkg.contains('woori') || pkg.contains('hana') ||
        pkg.contains('stock') || pkg.contains('kakaopay') ||
        pkg.contains('naverpay')) {
      return AppCategory.finance;
    }
    // Productivity
    if (pkg.contains('notion') || pkg.contains('slack') ||
        pkg.contains('docs') || pkg.contains('sheets') ||
        pkg.contains('drive') || pkg.contains('github') ||
        pkg.contains('calendar') || pkg.contains('office') ||
        pkg.contains('evernote') || pkg.contains('todoist')) {
      return AppCategory.productivity;
    }
    // Education
    if (pkg.contains('duolingo') || pkg.contains('coursera') ||
        pkg.contains('udemy') || pkg.contains('classin') ||
        pkg.contains('megastudy') || pkg.contains('hackers')) {
      return AppCategory.education;
    }
    // Health
    if (pkg.contains('health') || pkg.contains('fitness') ||
        pkg.contains('strava') || pkg.contains('nike')) {
      return AppCategory.health;
    }
    // Game (broad detection)
    if (pkg.contains('game') || pkg.contains('nexon') ||
        pkg.contains('netmarble') || pkg.contains('ncsoft') ||
        pkg.contains('supercell') || pkg.contains('rovio') ||
        pkg.contains('puzzle') || pkg.contains('craft')) {
      return AppCategory.game;
    }
    return AppCategory.other;
  }

  static String categoryKorean(AppCategory cat) {
    switch (cat) {
      case AppCategory.sns: return 'SNS';
      case AppCategory.game: return '게임';
      case AppCategory.entertainment: return '엔터테인먼트';
      case AppCategory.productivity: return '생산성';
      case AppCategory.communication: return '커뮤니케이션';
      case AppCategory.education: return '교육';
      case AppCategory.shopping: return '쇼핑';
      case AppCategory.finance: return '금융';
      case AppCategory.health: return '건강';
      case AppCategory.other: return '기타';
    }
  }
}

class ScreenTimeData {
  final String date;
  final int totalTimeMs;
  final int unlockCount;
  final List<AppUsageInfo> apps;
  final List<int> hourlyUsageMs;

  const ScreenTimeData({
    required this.date,
    required this.totalTimeMs,
    required this.unlockCount,
    required this.apps,
    required this.hourlyUsageMs,
  });

  String get formattedTotalTime => _formatDuration(totalTimeMs);

  List<AppUsageInfo> get topApps {
    final sorted = List<AppUsageInfo>.from(apps)
      ..sort((a, b) => b.totalTimeMs.compareTo(a.totalTimeMs));
    return sorted.take(10).toList();
  }

  Map<AppCategory, int> get categoryBreakdown {
    final map = <AppCategory, int>{};
    for (final app in apps) {
      map[app.category] = (map[app.category] ?? 0) + app.totalTimeMs;
    }
    // Sort by time descending
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  static String _formatDuration(int ms) {
    final totalMin = ms ~/ 60000;
    final hours = totalMin ~/ 60;
    final minutes = totalMin % 60;
    if (hours > 0) return '$hours시간 $minutes분';
    return '$minutes분';
  }

  static String formatDuration(int ms) => _formatDuration(ms);

  Map<String, dynamic> toJson() => {
    'date': date,
    'totalTimeMs': totalTimeMs,
    'unlockCount': unlockCount,
    'apps': apps.map((a) => a.toJson()).toList(),
    'hourlyUsageMs': hourlyUsageMs,
  };

  factory ScreenTimeData.fromJson(Map<String, dynamic> json) => ScreenTimeData(
    date: json['date'] as String? ?? '',
    totalTimeMs: json['totalTimeMs'] as int? ?? 0,
    unlockCount: json['unlockCount'] as int? ?? 0,
    apps: (json['apps'] as List?)?.map((e) => AppUsageInfo.fromJson(e)).toList() ?? [],
    hourlyUsageMs: (json['hourlyUsageMs'] as List?)?.cast<int>() ?? List.filled(24, 0),
  );
}
