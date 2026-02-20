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
  bool isAllDay; // true = no specific time (free routine)
  String? linkedAlarmId; // alarm ID for start notification
  String? linkedTimerId; // timer preset ID for focus timer

  // Per-routine overlay settings
  bool overlayEnabled;
  bool appLockEnabled;

  // Per-routine nag settings
  bool nagEnabled;
  int nagFrequency; // seconds between nags
  int nagIntensity; // 0=soft, 1=normal, 2=strict

  // Work type (null = always active regardless of work type)
  String? workTypeId;

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
    this.isAllDay = false,
    this.linkedAlarmId,
    this.linkedTimerId,
    this.overlayEnabled = true,
    this.appLockEnabled = false,
    this.nagEnabled = true,
    this.nagFrequency = 30,
    this.nagIntensity = 1,
    this.workTypeId,
  }) : activeDays = activeDays ?? List.filled(7, true);

  /// Check if this routine is active on a specific date (considering startDate and activeDays).
  /// Note: does NOT check isEnabled — callers decide whether to filter by enabled status.
  bool isActiveOnDate(DateTime date) {
    if (startDate != null) {
      final parts = startDate!.split('-');
      if (parts.length == 3) {
        final sd = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final dateOnly = DateTime(date.year, date.month, date.day);
        if (dateOnly.isBefore(sd)) return false;
      }
    }
    final dayIndex = date.weekday - 1;
    return activeDays[dayIndex];
  }

  bool isActiveNow() {
    if (!isEnabled) return false;
    final now = DateTime.now();
    if (!isActiveOnDate(now)) return false;

    if (isAllDay) return true;

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;

    if (startMinutes <= endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } else {
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
        'isAllDay': isAllDay,
        'linkedAlarmId': linkedAlarmId,
        'linkedTimerId': linkedTimerId,
        'overlayEnabled': overlayEnabled,
        'appLockEnabled': appLockEnabled,
        'nagEnabled': nagEnabled,
        'nagFrequency': nagFrequency,
        'nagIntensity': nagIntensity,
        'workTypeId': workTypeId,
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
        isAllDay: json['isAllDay'] ?? false,
        linkedAlarmId: json['linkedAlarmId'] as String?,
        linkedTimerId: json['linkedTimerId'] as String?,
        overlayEnabled: json['overlayEnabled'] ?? true,
        appLockEnabled: json['appLockEnabled'] ?? false,
        nagEnabled: json['nagEnabled'] ?? true,
        nagFrequency: json['nagFrequency'] ?? 30,
        nagIntensity: json['nagIntensity'] ?? 1,
        workTypeId: json['workTypeId'] as String?,
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
