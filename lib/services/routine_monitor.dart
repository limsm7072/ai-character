import 'dart:async';
import '../models/routine.dart';
import 'app_detection_service.dart';
import 'character_controller.dart';
import 'routine_service.dart';
import 'routine_completion_service.dart';
import 'settings_service.dart';

/// Monitors active routines and triggers character responses
/// when the user is distracted (using blocked apps).
/// Uses Android foreground service for reliable background detection.
class RoutineMonitor {
  final RoutineService _routineService;
  final AppDetectionService _appDetection;
  final CharacterController _characterController;
  final RoutineCompletionService _completionService;
  final SettingsService _settings;

  StreamSubscription? _distractionSub;
  Timer? _routineCheckTimer;
  bool _wasInRoutine = false;
  Routine? _activeRoutine;

  /// Track which routines we already prompted per date, so we don't repeat.
  /// Key: date string (yyyy-MM-dd), Value: set of routine IDs prompted.
  final Map<String, Set<String>> _promptedDates = {};

  /// Last time we ran the past-routine check (for throttling).
  DateTime? _lastPastCheckTime;

  RoutineMonitor({
    required RoutineService routineService,
    required AppDetectionService appDetection,
    required CharacterController characterController,
    required RoutineCompletionService completionService,
    required SettingsService settings,
  })  : _routineService = routineService,
        _appDetection = appDetection,
        _characterController = characterController,
        _completionService = completionService,
        _settings = settings;

  Future<void> start() async {
    // Start native foreground service for background monitoring
    await _appDetection.startMonitorService();

    // Listen for distraction events from native service
    _distractionSub = _appDetection.onDistraction.listen(_onDistraction);

    // Periodic check for routine start/end
    _routineCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkRoutineStatus(),
    );
  }

  void stop() {
    _distractionSub?.cancel();
    _routineCheckTimer?.cancel();
    _appDetection.stopMonitorService();
  }

  void _onDistraction(Map<String, String> event) async {
    try {
      // Only handle distractions during active routines
      if (_routineService.getActiveRoutine() == null) return;

      final appLabel = event['app_label'] ?? '';
      final appPackage = event['app_package'] ?? '';
      final routineName = event['routine_name'] ?? '루틴';

      await _characterController.onDistraction(
        appPackageName: appPackage,
        appLabel: appLabel,
        routineName: routineName,
      );

      // After distraction handling finishes (_isBusy is now false),
      // immediately check for unchecked past routines
      await _checkUncheckedPastRoutines();
    } catch (e) {
      print('RoutineMonitor distraction error: $e');
    }
  }

  void _checkRoutineStatus() async {
    try {
      final routine = _routineService.getActiveRoutine();

      // Routine just started
      if (routine != null && !_wasInRoutine) {
        _activeRoutine = routine;
        _wasInRoutine = true;
        await _characterController.onRoutineStart(routine.name);
        return;
      }

      // Routine just ended
      if (routine == null && _wasInRoutine) {
        final prev = _activeRoutine;
        _activeRoutine = null;
        _wasInRoutine = false;

        // Check if the routine was disabled (not actually ended by time)
        if (prev != null) {
          final fresh = _routineService.getAll().where((r) => r.id == prev.id).firstOrNull;
          if (fresh != null && !fresh.isEnabled) {
            // Routine was disabled, not ended — skip completion prompt
            return;
          }
        }

        final id = prev?.id ?? '';
        final name = prev?.name ?? '루틴';
        final today = _completionService.todayStr();
        final shown = await _characterController.onRoutineComplete(id, name, today, 0);
        if (shown) {
          _promptedDates.putIfAbsent(today, () => {}).add(id);
        }
        return;
      }

      _activeRoutine = routine;

      // Always check for past unchecked routines
      await _checkUncheckedPastRoutines();
    } catch (e) {
      print('RoutineMonitor check error: $e');
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Find routines from the past 7 days that haven't been completion-checked,
  /// and prompt the user once per routine per date.
  Future<void> _checkUncheckedPastRoutines() async {
    // Throttle: only run every routineCheckInterval seconds
    final now = DateTime.now();
    final interval = _settings.routineCheckInterval;
    if (_lastPastCheckTime != null &&
        now.difference(_lastPastCheckTime!).inSeconds < interval) {
      return;
    }
    _lastPastCheckTime = now;

    // Clean up old prompted dates (older than 7 days)
    final cutoffDate = now.subtract(const Duration(days: 8));
    final cutoffStr = _formatDate(cutoffDate);
    _promptedDates.removeWhere((date, _) => date.compareTo(cutoffStr) <= 0);

    final nowMinutes = now.hour * 60 + now.minute;
    final routines = _routineService.getAll();

    // Check days from most recent (today=0) to 6 days ago
    for (int i = 0; i <= 6; i++) {
      final targetDate = now.subtract(Duration(days: i));
      final dateStr = _formatDate(targetDate);
      final dayIndex = targetDate.weekday - 1; // 0=Mon, 6=Sun

      final prompted = _promptedDates.putIfAbsent(dateStr, () => {});

      for (final r in routines) {
        if (!r.isEnabled) continue;
        if (!r.activeDays[dayIndex]) continue;
        if (_completionService.hasRecord(r.id, dateStr)) continue;
        // No record → if previously prompted, user manually unchecked → re-ask
        prompted.remove(r.id);

        if (i == 0) {
          // Today: only check routines whose end time has passed
          final endMinutes = r.endTime.hour * 60 + r.endTime.minute;
          final startMinutes = r.startTime.hour * 60 + r.startTime.minute;

          bool hasEnded;
          if (startMinutes <= endMinutes) {
            hasEnded = nowMinutes > endMinutes;
          } else {
            hasEnded = nowMinutes > endMinutes && nowMinutes < startMinutes;
          }

          if (!hasEnded) continue;
        }
        // i > 0: past day — entire day has passed, always eligible

        final shown = await _characterController.onRoutineComplete(
          r.id, r.name, dateStr, i,
        );
        if (shown) {
          prompted.add(r.id);
        }
        // Only try one per tick (retry next tick if busy)
        return;
      }
    }
  }

  void dispose() {
    stop();
  }
}
