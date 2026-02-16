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

  RoutineMonitor({
    required RoutineService routineService,
    required AppDetectionService appDetection,
    required CharacterController characterController,
    required RoutineCompletionService completionService,
  })  : _routineService = routineService,
        _appDetection = appDetection,
        _characterController = characterController,
        _completionService = completionService;

  // ─── Lifecycle ──────────────────────────────────────────

  Future<void> start() async {
    await _appDetection.startMonitorService();
    _distractionSub = _appDetection.onDistraction.listen(_onDistraction);
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

  void dispose() => stop();

  /// Force an immediate unchecked-routine check (e.g. after user cancels completion).
  void forceCheck() {
    _checkUncheckedPastRoutines();
  }

  // ─── Distraction handling ───────────────────────────────

  void _onDistraction(Map<String, String> event) async {
    try {
      if (_routineService.getActiveRoutine() == null) return;

      await _characterController.onDistraction(
        appPackageName: event['app_package'] ?? '',
        appLabel: event['app_label'] ?? '',
        routineName: event['routine_name'] ?? '루틴',
      );

      await _checkUncheckedPastRoutines();
    } catch (e) {
      print('RoutineMonitor distraction error: $e');
    }
  }

  // ─── Routine status check (every 10s) ───────────────────

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

      // Routine changed (A ended → B started immediately)
      if (routine != null && _wasInRoutine && _activeRoutine != null &&
          routine.id != _activeRoutine!.id) {
        final prev = _activeRoutine!;
        _activeRoutine = routine;
        await _promptCompletion(prev.id, prev.name, _completionService.todayStr(), 0);
        return;
      }

      // Routine just ended
      if (routine == null && _wasInRoutine) {
        final prev = _activeRoutine;
        _activeRoutine = null;
        _wasInRoutine = false;

        if (prev != null && _wasDisabledByUser(prev.id)) return;

        final today = _completionService.todayStr();
        await _promptCompletion(prev?.id ?? '', prev?.name ?? '루틴', today, 0);
        return;
      }

      // Idle — check for unchecked past routines
      _activeRoutine = routine;
      await _checkUncheckedPastRoutines();
    } catch (e) {
      print('RoutineMonitor check error: $e');
    }
  }

  // ─── Past routine completion check ──────────────────────

  /// Scans routines from today to 6 days ago. If a routine's time has passed
  /// and no completion record exists, prompts the user. Only one prompt per tick.
  Future<void> _checkUncheckedPastRoutines() async {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final routines = _routineService.getAll();

    for (int daysAgo = 0; daysAgo <= 6; daysAgo++) {
      final targetDate = now.subtract(Duration(days: daysAgo));
      final dateStr = _formatDate(targetDate);

      for (final r in routines) {
        if (!r.isActiveOnDate(targetDate)) continue;
        if (_completionService.hasRecord(r.id, dateStr)) continue;
        if (daysAgo == 0 && !_hasRoutineEnded(r, nowMinutes)) continue;

        await _promptCompletion(r.id, r.name, dateStr, daysAgo);
        return; // One prompt per tick
      }
    }
  }

  // ─── Helpers ────────────────────────────────────────────

  Future<void> _promptCompletion(String id, String name, String dateStr, int daysAgo) async {
    if (_completionService.hasRecord(id, dateStr)) return;
    await _characterController.onRoutineComplete(id, name, dateStr, daysAgo);
  }

  bool _hasRoutineEnded(Routine r, int nowMinutes) {
    final startMin = r.startTime.hour * 60 + r.startTime.minute;
    final endMin = r.endTime.hour * 60 + r.endTime.minute;

    if (startMin <= endMin) {
      return nowMinutes > endMin;
    } else {
      return nowMinutes > endMin && nowMinutes < startMin;
    }
  }

  bool _wasDisabledByUser(String routineId) {
    final fresh = _routineService.getAll().where((r) => r.id == routineId).firstOrNull;
    return fresh != null && !fresh.isEnabled;
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
