import 'dart:convert';

class CalendarEvent {
  String id;
  String title;
  String description;
  String date; // yyyy-MM-dd
  int? startHour;
  int? startMinute;
  int? endHour;
  int? endMinute;
  String color; // hex color e.g. '#2196F3'
  bool isDDay;
  DateTime createdAt;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    this.startHour,
    this.startMinute,
    this.endHour,
    this.endMinute,
    this.color = '#2196F3',
    this.isDDay = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get timeString {
    if (startHour == null) return '종일';
    final start = '${startHour!.toString().padLeft(2, '0')}:${(startMinute ?? 0).toString().padLeft(2, '0')}';
    if (endHour == null) return start;
    final end = '${endHour!.toString().padLeft(2, '0')}:${(endMinute ?? 0).toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  /// D-Day string relative to today (e.g. "D-30", "D-Day", "D+5")
  String dDayString([DateTime? now]) {
    final today = now ?? DateTime.now();
    final eventDate = DateTime.parse(date);
    final todayOnly = DateTime(today.year, today.month, today.day);
    final eventOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final diff = eventOnly.difference(todayOnly).inDays;
    if (diff == 0) return 'D-Day';
    if (diff > 0) return 'D-$diff';
    return 'D+${-diff}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'color': color,
        'isDDay': isDDay,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'],
        title: json['title'],
        description: json['description'] ?? '',
        date: json['date'],
        startHour: json['startHour'],
        startMinute: json['startMinute'],
        endHour: json['endHour'],
        endMinute: json['endMinute'],
        color: json['color'] ?? '#2196F3',
        isDDay: json['isDDay'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
      );

  static String encode(List<CalendarEvent> events) =>
      jsonEncode(events.map((e) => e.toJson()).toList());

  static List<CalendarEvent> decode(String source) =>
      (jsonDecode(source) as List).map((j) => CalendarEvent.fromJson(j)).toList();
}
