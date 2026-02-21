import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../services/alarm_service.dart';
import '../service_locator.dart';
import '../theme/app_colors.dart';

class AlarmRingScreen extends StatefulWidget {
  final String alarmLabel;

  const AlarmRingScreen({
    super.key,
    required this.alarmLabel,
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  static const _audioChannel =
      MethodChannel('com.aicharacter.ai_character/audio');

  final SettingsService _settingsService = getIt<SettingsService>();
  late final bool _shakeEnabled;
  late final int _shakeTarget;
  int _shakeCount = 0;
  Timer? _clockTimer;
  String _currentTime = '';
  late AnimationController _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeEnabled = _settingsService.shakeToDisable;
    _shakeTarget = _settingsService.shakeCount;
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    _shakeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    // AlarmRingService is already playing sound via native foreground service.
    // If opened from notification tap (old path), play alarm as fallback.
    _playAlarmFallback();
    if (_shakeEnabled) {
      _startShakeDetection();
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  /// Fallback: play alarm via audio channel if service isn't running
  Future<void> _playAlarmFallback() async {
    try {
      await _audioChannel.invokeMethod('playAlarm');
    } catch (_) {}
  }

  Future<void> _stopAllAlarmSounds() async {
    // Stop native AlarmRingService (foreground service)
    await AlarmService.stopAlarmRing();
    // Also stop audio channel alarm (fallback)
    try {
      await _audioChannel.invokeMethod('stopAlarm');
    } catch (_) {}
  }

  Future<void> _startShakeDetection() async {
    try {
      _audioChannel.setMethodCallHandler((call) async {
        if (call.method == 'onShake') {
          _onShake();
        }
      });
      await _audioChannel.invokeMethod('startShakeDetection');
    } catch (e) {
      print('[AlarmRingScreen] startShakeDetection error: $e');
    }
  }

  Future<void> _stopShakeDetection() async {
    try {
      await _audioChannel.invokeMethod('stopShakeDetection');
      _audioChannel.setMethodCallHandler(null);
    } catch (e) {
      print('[AlarmRingScreen] stopShakeDetection error: $e');
    }
  }

  void _onShake() {
    if (_shakeCount >= _shakeTarget) return;
    setState(() {
      _shakeCount++;
    });
    HapticFeedback.mediumImpact();
    if (_shakeCount >= _shakeTarget) {
      _dismiss();
    }
  }

  Future<void> _dismiss() async {
    await _stopAllAlarmSounds();
    if (_shakeEnabled) {
      await _stopShakeDetection();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _shakeAnim.dispose();
    _stopAllAlarmSounds();
    if (_shakeEnabled) {
      _stopShakeDetection();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _shakeEnabled ? _shakeCount / _shakeTarget : 0.0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // Current time
                  Text(
                    _currentTime,
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Alarm label
                  Text(
                    widget.alarmLabel,
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  if (_shakeEnabled) ...[
                    // Shake progress
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _shakeCount >= _shakeTarget
                                    ? AppColors.success
                                    : AppColors.accent,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Shake animation icon
                              AnimatedBuilder(
                                animation: _shakeAnim,
                                builder: (_, child) {
                                  final offset =
                                      sin(_shakeAnim.value * pi * 2) * 8;
                                  return Transform.translate(
                                    offset: Offset(offset, 0),
                                    child: child,
                                  );
                                },
                                child: Icon(
                                  Icons.phone_android,
                                  size: 40,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_shakeCount / $_shakeTarget회',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '기기를 흔들어 알람을 끄세요!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ] else ...[
                    // Simple dismiss button when shake is disabled
                    SizedBox(
                      width: 200,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _dismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text(
                          '알람 끄기',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
