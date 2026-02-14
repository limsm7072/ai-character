import 'dart:async';
import '../models/routine.dart';
import 'app_detection_service.dart';
import 'character_controller.dart';
import 'routine_service.dart';

/// Monitors active routines and triggers character responses
/// when the user is distracted (using blocked apps).
/// Uses Android foreground service for reliable background detection.
class RoutineMonitor {
  final RoutineService _routineService;
  final AppDetectionService _appDetection;
  final CharacterController _characterController;

  StreamSubscription? _distractionSub;
  Timer? _routineCheckTimer;
  bool _wasInRoutine = false;
  Routine? _activeRoutine;

  RoutineMonitor({
    required RoutineService routineService,
    required AppDetectionService appDetection,
    required CharacterController characterController,
  })  : _routineService = routineService,
        _appDetection = appDetection,
        _characterController = characterController;

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
    final appLabel = event['app_label'] ?? '';
    final appPackage = event['app_package'] ?? '';
    final routineName = event['routine_name'] ?? '루틴';

    await _characterController.onDistraction(
      appPackageName: appPackage,
      appLabel: appLabel,
      routineName: routineName,
    );
  }

  void _checkRoutineStatus() async {
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
      final name = _activeRoutine?.name ?? '루틴';
      _activeRoutine = null;
      _wasInRoutine = false;
      await _characterController.onRoutineComplete(name);
      return;
    }

    _activeRoutine = routine;
  }

  void dispose() {
    stop();
  }
}
