import 'package:flutter/material.dart';

enum ActivityType {
  walking,
  running,
  cycling,
  vehicle,
  still,
  unknown,
}

class ActivityEntry {
  final ActivityType type;
  final String transition; // ENTER or EXIT
  final int timestamp;

  const ActivityEntry({
    required this.type,
    required this.transition,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'transition': transition,
    'timestamp': timestamp,
  };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
    type: ActivityType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ActivityType.unknown,
    ),
    transition: json['transition'] as String? ?? '',
    timestamp: json['timestamp'] as int? ?? 0,
  );
}

class ActivitySegment {
  final ActivityType type;
  final int startMs;
  final int endMs;

  const ActivitySegment({required this.type, required this.startMs, required this.endMs});

  int get durationMinutes => ((endMs - startMs) / 60000).round();
}

class ActivitySummary {
  final String date;
  final List<ActivityEntry> entries;

  const ActivitySummary({required this.date, required this.entries});

  List<ActivitySegment> get timeline {
    final segments = <ActivitySegment>[];
    final activeStarts = <ActivityType, int>{};

    for (final entry in entries) {
      if (entry.type == ActivityType.unknown) continue;
      if (entry.transition == 'ENTER') {
        activeStarts[entry.type] = entry.timestamp;
      } else if (entry.transition == 'EXIT') {
        final start = activeStarts.remove(entry.type);
        if (start != null && entry.timestamp > start) {
          segments.add(ActivitySegment(type: entry.type, startMs: start, endMs: entry.timestamp));
        }
      }
    }

    // Still-active segments: close at now
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in activeStarts.entries) {
      segments.add(ActivitySegment(type: entry.key, startMs: entry.value, endMs: now));
    }

    segments.sort((a, b) => a.startMs.compareTo(b.startMs));
    return segments;
  }

  int _minutesOf(ActivityType type) {
    return timeline
        .where((s) => s.type == type)
        .fold<int>(0, (sum, s) => sum + s.durationMinutes);
  }

  int get walkingMinutes => _minutesOf(ActivityType.walking);
  int get runningMinutes => _minutesOf(ActivityType.running);
  int get cyclingMinutes => _minutesOf(ActivityType.cycling);
  int get vehicleMinutes => _minutesOf(ActivityType.vehicle);
  int get stillMinutes => _minutesOf(ActivityType.still);

  Map<String, dynamic> toJson() => {
    'date': date,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory ActivitySummary.fromJson(Map<String, dynamic> json) => ActivitySummary(
    date: json['date'] as String? ?? '',
    entries: (json['entries'] as List?)?.map((e) => ActivityEntry.fromJson(e)).toList() ?? [],
  );

  static String activityKorean(ActivityType type) {
    switch (type) {
      case ActivityType.walking: return '걷기';
      case ActivityType.running: return '달리기';
      case ActivityType.cycling: return '자전거';
      case ActivityType.vehicle: return '차량';
      case ActivityType.still: return '정지';
      case ActivityType.unknown: return '알 수 없음';
    }
  }

  static IconData activityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.walking: return Icons.directions_walk;
      case ActivityType.running: return Icons.directions_run;
      case ActivityType.cycling: return Icons.directions_bike;
      case ActivityType.vehicle: return Icons.directions_car;
      case ActivityType.still: return Icons.accessibility_new;
      case ActivityType.unknown: return Icons.help_outline;
    }
  }

  static Color activityColor(ActivityType type) {
    switch (type) {
      case ActivityType.walking: return const Color(0xFF4CAF50);
      case ActivityType.running: return const Color(0xFFFF5722);
      case ActivityType.cycling: return const Color(0xFF2196F3);
      case ActivityType.vehicle: return const Color(0xFF9C27B0);
      case ActivityType.still: return const Color(0xFF9E9E9E);
      case ActivityType.unknown: return const Color(0xFFBDBDBD);
    }
  }
}
