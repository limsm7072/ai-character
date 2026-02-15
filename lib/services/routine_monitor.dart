import 'dart:async';
import '../models/routine.dart';
import 'app_detection_service.dart';
import 'character_controller.dart';
import 'routine_service.dart';
import 'routine_completion_service.dart';

/// Monitors active routines and triggers character responses
/// when the user is distracted (using blocked apps).
/// Uses Android foreground service for reliable background detection.
class RoutineMonitor {
  final RoutineService _routineService;
  final AppDetectionService _appDetection;
  final CharacterController _characterController;
  final RoutineCompletionService _completionService;

  StreamSubscription? _distractionSub;
  Timer? _routineCheckTimer;
  bool _wasInRoutine = false;
  Routine? _activeRoutine;

  /// Track which routines we already prompted today, so we don't repeat.
  final Set<String> _promptedToday = {};
  String _promptedDate = '';

  RoutineMonitor({
    required RoutineService routineService,
    required AppDetectionService appDetection,
    required CharacterController characterController,
    required RoutineCompletionService completionService,
  })  : _routineService = routineService,
        _appDetection = appDetection,
        _characterController = characterController,
        _completionService = completionService;

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
        final shown = await _characterController.onRoutineComplete(id, name);
        if (shown) _promptedToday.add(id);
        return;
      }

      _activeRoutine = routine;

      // Always check for past unchecked routines
      // (even during active routine — a different past routine may need checking)
      await _checkUncheckedPastRoutines();
    } catch (e) {
      print('RoutineMonitor check error: $e');
    }
  }

  /// Find routines that ended today but haven't been completion-checked,
  /// and prompt the user once per routine per day.
  Future<void> _checkUncheckedPastRoutines() async {
    final today = _completionService.todayStr();

    // Reset prompted set on new day
    if (_promptedDate != today) {
      _promptedToday.clear();
      _promptedDate = today;
    }

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final dayIndex = now.weekday - 1;

    final routines = _routineService.getAll();

    for (final r in routines) {
      if (!r.isEnabled) continue;
      if (!r.activeDays[dayIndex]) continue;
      if (_promptedToday.contains(r.id)) continue;
      if (_completionService.isCompleted(r.id, today)) continue;

      final endMinutes = r.endTime.hour * 60 + r.endTime.minute;
      final startMinutes = r.startTime.hour * 60 + r.startTime.minute;

      // Only consider non-overnight routines that have ended
      bool hasEnded;
      if (startMinutes <= endMinutes) {
        hasEnded = nowMinutes > endMinutes;
      } else {
        // Overnight routine — ended if past end time and before start time
        hasEnded = nowMinutes > endMinutes && nowMinutes < startMinutes;
      }

      if (hasEnded) {
        final shown =
            await _characterController.onRoutineComplete(r.id, r.name);
        if (shown) {
          _promptedToday.add(r.id);
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
