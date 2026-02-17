import 'dart:convert';

class Alarm {
  String id;
  String label;
  int hour; // 0-23
  int minute; // 0-59
  List<bool> activeDays; // [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
  bool isEnabled;
  DateTime createdAt;

  Alarm({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    List<bool>? activeDays,
    this.isEnabled = true,
    DateTime? createdAt,
  })  : activeDays = activeDays ?? List.filled(7, false),
        createdAt = createdAt ?? DateTime.now();

  bool get isOneTime => activeDays.every((d) => !d);

  int get notificationId => 10000 + (id.hashCode.abs() % 9000);

  String get timeString =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get daysString {
    if (isOneTime) return '한 번';
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final active = <String>[];
    for (int i = 0; i < 7; i++) {
      if (activeDays[i]) active.add(dayNames[i]);
    }
    if (active.length == 7) return '매일';
    if (active.length == 5 &&
        activeDays[0] && activeDays[1] && activeDays[2] &&
        activeDays[3] && activeDays[4]) return '평일';
    if (active.length == 2 && activeDays[5] && activeDays[6]) return '주말';
    return active.join(' ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'hour': hour,
        'minute': minute,
        'activeDays': activeDays,
        'isEnabled': isEnabled,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Alarm.fromJson(Map<String, dynamic> json) => Alarm(
        id: json['id'],
        label: json['label'],
        hour: json['hour'],
        minute: json['minute'],
        activeDays: (json['activeDays'] as List).cast<bool>(),
        isEnabled: json['isEnabled'] ?? true,
        createdAt: DateTime.parse(json['createdAt']),
      );

  static String encode(List<Alarm> alarms) =>
      jsonEncode(alarms.map((a) => a.toJson()).toList());

  static List<Alarm> decode(String source) =>
      (jsonDecode(source) as List).map((j) => Alarm.fromJson(j)).toList();
}
