class Routine {
  final String id;
  String name;
  String description;
  String? startDate; // yyyy-MM-dd, null = immediately active
  TimeOfDay startTime;
  TimeOfDay endTime;
  List<String> blockedApps; // package names to block
  List<bool> activeDays; // Mon-Sun (7 elements)
  bool isEnabled;

  Routine({
    required this.id,
    required this.name,
    this.description = '',
    this.startDate,
    required this.startTime,
    required this.endTime,
    this.blockedApps = const [],
    List<bool>? activeDays,
    this.isEnabled = true,
  }) : activeDays = activeDays ?? List.filled(7, true);

  bool isActiveNow() {
    if (!isEnabled) return false;
    final now = DateTime.now();
    final dayIndex = now.weekday - 1; // 0=Mon, 6=Sun
    if (!activeDays[dayIndex]) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;

    if (startMinutes <= endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } else {
      // Overnight routine (e.g., 22:00 - 06:00)
      return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'startDate': startDate,
        'startHour': startTime.hour,
        'startMinute': startTime.minute,
        'endHour': endTime.hour,
        'endMinute': endTime.minute,
        'blockedApps': blockedApps,
        'activeDays': activeDays,
        'isEnabled': isEnabled,
      };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
        id: json['id'],
        name: json['name'],
        description: json['description'] ?? '',
        startDate: json['startDate'],
        startTime: TimeOfDay(
          hour: json['startHour'],
          minute: json['startMinute'],
        ),
        endTime: TimeOfDay(
          hour: json['endHour'],
          minute: json['endMinute'],
        ),
        blockedApps: List<String>.from(json['blockedApps'] ?? []),
        activeDays: List<bool>.from(json['activeDays'] ?? List.filled(7, true)),
        isEnabled: json['isEnabled'] ?? true,
      );
}

class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  String format() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  String toString() => format();
}
