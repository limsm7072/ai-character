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
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
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

  static List<TimerPreset> defaults() => [
        TimerPreset(id: 'default_5', label: '5분', durationSeconds: 300),
        TimerPreset(id: 'default_10', label: '10분', durationSeconds: 600),
        TimerPreset(id: 'default_30', label: '30분', durationSeconds: 1800),
        TimerPreset(
          id: 'default_pomo',
          label: '뽀모도로',
          durationSeconds: 1500,
          isPomodoro: true,
          focusMinutes: 25,
          breakMinutes: 5,
          targetSessions: 4,
        ),
      ];
}
