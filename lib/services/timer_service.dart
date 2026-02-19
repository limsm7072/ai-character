import 'package:shared_preferences/shared_preferences.dart';
import '../models/timer_preset.dart';
import 'notification_service.dart';

class TimerService {
  static const _key = 'timer_presets_data';
  static const int _timerAlarmId = NotificationService.timerBase + 100;
  final SharedPreferences _prefs;
  final NotificationService _notification;
  List<TimerPreset> _presets = [];

  TimerService(this._prefs, this._notification) {
    _load();
  }

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      _presets = TimerPreset.decode(raw);
    } else {
      _presets = TimerPreset.defaults();
      _save();
    }
  }

  Future<void> _save() async {
    await _prefs.setString(_key, TimerPreset.encode(_presets));
  }

  List<TimerPreset> getAll() => List.unmodifiable(_presets);

  Future<TimerPreset> add(TimerPreset preset) async {
    _presets.add(preset);
    await _save();
    return preset;
  }

  Future<void> update(TimerPreset preset) async {
    final idx = _presets.indexWhere((p) => p.id == preset.id);
    if (idx >= 0) {
      _presets[idx] = preset;
      await _save();
    }
  }

  Future<void> delete(String id) async {
    _presets.removeWhere((p) => p.id == id);
    await _save();
  }

  /// 타이머 시작 시 백그라운드 알림 예약 (앱이 꺼져도 소리남)
  Future<void> scheduleTimerAlarm(int delaySeconds, String label) async {
    await cancelTimerAlarm();
    final fireTime = DateTime.now().add(Duration(seconds: delaySeconds));
    await _notification.scheduleExact(
      id: _timerAlarmId,
      title: '타이머 완료',
      body: '$label 타이머가 끝났습니다!',
      dateTime: fireTime,
      channelId: NotificationService.timerChannelId,
      channelName: '타이머',
    );
  }

  /// 타이머 일시정지/리셋 시 예약 취소
  Future<void> cancelTimerAlarm() async {
    await _notification.cancel(_timerAlarmId);
  }

  Future<void> notifyTimerComplete(String label) async {
    await _notification.showImmediate(
      id: NotificationService.timerBase,
      title: '타이머 완료',
      body: '$label 타이머가 끝났습니다!',
      channelId: NotificationService.timerChannelId,
      channelName: '타이머',
    );
  }

  Future<void> notifyPomodoroPhase({required bool isFocus, required int session, required int total}) async {
    await _notification.showImmediate(
      id: NotificationService.timerBase + 1,
      title: isFocus ? '집중 시간!' : '휴식 시간!',
      body: isFocus ? '세션 $session/$total 시작' : '잠시 쉬어가세요~',
      channelId: NotificationService.timerChannelId,
      channelName: '타이머',
    );
  }
}
