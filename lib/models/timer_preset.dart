import 'dart:convert';

class TimerPreset {
  String id;
  String label;
  int durationSeconds;
  bool isPomodoro;
  int focusMinutes;
  int breakMinutes;
  int targetSessions;
  DateTime createdAt;

  TimerPreset({
    required this.id,
    required this.label,
    required this.durationSeconds,
    this.isPomodoro = false,
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.targetSessions = 4,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get durationString {
    if (isPomodoro) return '${focusMinutes}/${breakMinutes}분 ${targetSessions}세션';
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0 && m > 0) return '${h}시간 ${m}분';
    if (h > 0) return '${h}시간';
    if (s == 0) return '${m}분';
    return '${m}분 ${s}초';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'durationSeconds': durationSeconds,
        'isPomodoro': isPomodoro,
        'focusMinutes': focusMinutes,
        'breakMinutes': breakMinutes,
        'targetSessions': targetSessions,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TimerPreset.fromJson(Map<String, dynamic> json) => TimerPreset(
        id: json['id'],
        label: json['label'],
        durationSeconds: json['durationSeconds'],
        isPomodoro: json['isPomodoro'] ?? false,
        focusMinutes: json['focusMinutes'] ?? 25,
        breakMinutes: json['breakMinutes'] ?? 5,
        targetSessions: json['targetSessions'] ?? 4,
        createdAt: DateTime.parse(json['createdAt']),
      );

  static String encode(List<TimerPreset> presets) =>
      jsonEncode(presets.map((p) => p.toJson()).toList());

  static List<TimerPreset> decode(String source) =>
      (jsonDecode(source) as List).map((j) => TimerPreset.fromJson(j)).toList();

  static List<TimerPreset> defaults() => [];
}
