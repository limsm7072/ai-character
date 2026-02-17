import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _canScheduleExact = false;
  bool _hasNotificationPermission = false;

  // ID namespaces
  static const int alarmBase = 10000;
  static const int timerBase = 20000;
  static const int routineBase = 30000;

  // Channel IDs
  static const String alarmChannelId = 'alarm_channel';
  static const String timerChannelId = 'timer_channel';
  static const String routineChannelId = 'routine_channel';

  bool get isInitialized => _initialized;
  bool get canScheduleExact => _canScheduleExact;
  bool get hasNotificationPermission => _hasNotificationPermission;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;

    // Check current permission status (don't request yet)
    await _checkPermissions();
  }

  /// Check current permission status without requesting.
  Future<void> _checkPermissions() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;

      _canScheduleExact = await android.canScheduleExactNotifications() ?? false;
      print('[NotificationService] canScheduleExact=$_canScheduleExact');
    } catch (e) {
      print('[NotificationService] _checkPermissions failed: $e');
    }
  }

  /// Request all needed permissions. Returns true if notification permission granted.
  Future<bool> requestPermissions() async {
    if (!_initialized) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;

      // Request POST_NOTIFICATIONS (Android 13+)
      _hasNotificationPermission = await android.requestNotificationsPermission() ?? false;
      print('[NotificationService] notificationPermission=$_hasNotificationPermission');

      // Request SCHEDULE_EXACT_ALARM (Android 12+) — opens system settings
      _canScheduleExact = await android.requestExactAlarmsPermission() ?? false;
      print('[NotificationService] exactAlarm=$_canScheduleExact');

      return _hasNotificationPermission;
    } catch (e) {
      print('[NotificationService] requestPermissions failed: $e');
      return false;
    }
  }

  /// Request only notification permission (no exact alarm).
  Future<bool> requestNotificationPermission() async {
    if (!_initialized) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;

      _hasNotificationPermission = await android.requestNotificationsPermission() ?? false;
      return _hasNotificationPermission;
    } catch (e) {
      print('[NotificationService] requestNotificationPermission failed: $e');
      return false;
    }
  }

  AndroidScheduleMode get _scheduleMode => _canScheduleExact
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  Future<void> scheduleExact({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String channelId = alarmChannelId,
    String channelName = '알람',
  }) async {
    if (!_initialized) {
      print('[NotificationService] scheduleExact: not initialized');
      return;
    }
    try {
      final scheduledDate = tz.TZDateTime.from(dateTime, tz.local);
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        print('[NotificationService] scheduleExact: time is in the past');
        return;
      }

      // Re-check exact alarm capability before scheduling
      await _checkPermissions();

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
          ),
        ),
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('[NotificationService] scheduleExact: id=$id at $scheduledDate mode=$_scheduleMode');
    } catch (e) {
      print('[NotificationService] scheduleExact failed: $e');
    }
  }

  Future<void> scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int dayOfWeek, // 1=Monday ... 7=Sunday (ISO)
    String channelId = alarmChannelId,
    String channelName = '알람',
  }) async {
    if (!_initialized) {
      print('[NotificationService] scheduleWeekly: not initialized');
      return;
    }
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = _nextDayOfWeek(now, dayOfWeek, hour, minute);

      // Re-check exact alarm capability before scheduling
      await _checkPermissions();

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
          ),
        ),
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      print('[NotificationService] scheduleWeekly: id=$id day=$dayOfWeek $hour:$minute mode=$_scheduleMode');
    } catch (e) {
      print('[NotificationService] scheduleWeekly failed: $e');
    }
  }

  tz.TZDateTime _nextDayOfWeek(tz.TZDateTime now, int dayOfWeek, int hour, int minute) {
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // Adjust to the correct day of week
    while (scheduled.weekday != dayOfWeek) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    // If it's in the past, move to next week
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
    String channelId = timerChannelId,
    String channelName = '타이머',
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    } catch (e) {
      print('[NotificationService] showImmediate failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id);
    } catch (e) {
      print('[NotificationService] cancel failed: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      print('[NotificationService] cancelAll failed: $e');
    }
  }

  /// Get list of pending notifications (for debugging).
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) return [];
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      print('[NotificationService] getPendingNotifications failed: $e');
      return [];
    }
  }
}
