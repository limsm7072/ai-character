import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/timer_preset.dart';
import '../services/timer_service.dart';
import '../theme/app_colors.dart';

// ─── Ambient Sound Types ──────────────────────────────

enum AmbientSound {
  none('없음', Icons.volume_off),
  white('백색소음', Icons.graphic_eq),
  pink('핑크노이즈', Icons.graphic_eq),
  brown('브라운노이즈', Icons.graphic_eq),
  rain('빗소리', Icons.water_drop),
  ocean('파도소리', Icons.waves);

  final String label;
  final IconData icon;
  const AmbientSound(this.label, this.icon);

  String get typeKey => name; // white, pink, brown, rain, ocean
}

// ─── Timer Screen ─────────────────────────────────────

class TimerScreen extends StatefulWidget {
  final TimerService timerService;
  final int? initialDurationSeconds;
  final String? initialLabel;

  const TimerScreen({
    super.key,
    required this.timerService,
    this.initialDurationSeconds,
    this.initialLabel,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('타이머'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '카운트다운'),
            Tab(text: '뽀모도로'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _CountdownTab(
              timerService: widget.timerService,
              initialDurationSeconds: widget.initialDurationSeconds,
              initialLabel: widget.initialLabel,
            ),
            _PomodoroTab(timerService: widget.timerService),
          ],
        ),
      ),
    );
  }
}

// ─── Ambient Sound Controls Widget ────────────────────

class _AmbientSoundControls extends StatelessWidget {
  final AmbientSound selectedSound;
  final double volume;
  final ValueChanged<AmbientSound> onSoundChanged;
  final ValueChanged<double> onVolumeChanged;
  final bool darkMode;

  const _AmbientSoundControls({
    required this.selectedSound,
    required this.volume,
    required this.onSoundChanged,
    required this.onVolumeChanged,
    this.darkMode = false,
  });

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkMode ? const Color(0xFF1E1E1E) : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: darkMode ? AppColors.grey600 : AppColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '배경음 선택',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                  color: darkMode ? AppColors.white : null,
                ),
              ),
              const SizedBox(height: 12),
              ...AmbientSound.values.map((s) {
                final isSelected = selectedSound == s;
                return ListTile(
                  leading: Icon(s.icon, color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : darkMode ? AppColors.grey400 : AppColors.grey600),
                  title: Text(s.label, style: TextStyle(
                    color: darkMode ? AppColors.white : null,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    onSoundChanged(s);
                    Navigator.pop(context);
                  },
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSound = selectedSound != AmbientSound.none;
    final iconColor = darkMode
        ? AppColors.white.withValues(alpha: 0.5)
        : AppColors.grey600;

    return Column(
      children: [
        // Single button
        GestureDetector(
          onTap: () => _showPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: darkMode
                  ? AppColors.white.withValues(alpha: hasSound ? 0.12 : 0.05)
                  : hasSound
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasSound ? selectedSound.icon : Icons.music_note,
                  size: 16,
                  color: darkMode
                      ? AppColors.white.withValues(alpha: 0.7)
                      : hasSound
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.grey600,
                ),
                const SizedBox(width: 6),
                Text(
                  hasSound ? selectedSound.label : '배경음',
                  style: TextStyle(
                    fontSize: 13,
                    color: darkMode
                        ? AppColors.white.withValues(alpha: 0.7)
                        : hasSound
                            ? Theme.of(context).colorScheme.primary
                            : AppColors.grey600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 16, color: iconColor),
              ],
            ),
          ),
        ),
        // Volume slider (only when sound selected)
        if (hasSound) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volume_down, size: 16, color: iconColor),
              SizedBox(
                width: 160,
                child: SliderTheme(
                  data: darkMode
                      ? SliderThemeData(
                          activeTrackColor: AppColors.white.withValues(alpha: 0.4),
                          inactiveTrackColor: AppColors.white.withValues(alpha: 0.1),
                          thumbColor: AppColors.white.withValues(alpha: 0.7),
                          overlayColor: AppColors.white.withValues(alpha: 0.1),
                        )
                      : const SliderThemeData(),
                  child: Slider(
                    value: volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: onVolumeChanged,
                  ),
                ),
              ),
              Icon(Icons.volume_up, size: 16, color: iconColor),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Countdown Tab ─────────────────────────────────────

class _CountdownTab extends StatefulWidget {
  final TimerService timerService;
  final int? initialDurationSeconds;
  final String? initialLabel;

  const _CountdownTab({
    required this.timerService,
    this.initialDurationSeconds,
    this.initialLabel,
  });

  @override
  State<_CountdownTab> createState() => _CountdownTabState();
}

class _CountdownTabState extends State<_CountdownTab> {
  static const _audioChannel = MethodChannel('com.aicharacter.ai_character/audio');

  Timer? _timer;
  int _totalSeconds = 300;
  int _remaining = 0;
  bool _isRunning = false;
  bool _isAlarmPlaying = false;
  String _selectedPresetId = '';

  // Ambient sound
  AmbientSound _ambientSound = AmbientSound.none;
  double _ambientVolume = 0.5;

  @override
  void initState() {
    super.initState();
    if (widget.initialDurationSeconds != null) {
      _totalSeconds = widget.initialDurationSeconds!;
      _remaining = _totalSeconds;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAlarm();
    _stopAmbient();
    super.dispose();
  }

  void _playAlarm() {
    _isAlarmPlaying = true;
    _audioChannel.invokeMethod('playAlarm');
  }

  void _stopAlarm() {
    if (_isAlarmPlaying) {
      _isAlarmPlaying = false;
      _audioChannel.invokeMethod('stopAlarm');
    }
  }

  void _startAmbient() {
    if (_ambientSound != AmbientSound.none) {
      _audioChannel.invokeMethod('startAmbient', {
        'type': _ambientSound.typeKey,
        'volume': _ambientVolume,
      });
    }
  }

  void _stopAmbient() {
    _audioChannel.invokeMethod('stopAmbient');
  }

  void _onAmbientChanged(AmbientSound sound) {
    setState(() => _ambientSound = sound);
    if (sound == AmbientSound.none) {
      _stopAmbient();
    } else if (_isRunning) {
      _audioChannel.invokeMethod('startAmbient', {
        'type': sound.typeKey,
        'volume': _ambientVolume,
      });
    }
  }

  void _onAmbientVolumeChanged(double vol) {
    setState(() => _ambientVolume = vol);
    if (_ambientSound != AmbientSound.none && _isRunning) {
      _audioChannel.invokeMethod('setAmbientVolume', {'volume': vol});
    }
  }

  void _selectPreset(TimerPreset preset) {
    if (preset.isPomodoro) return;
    _timer?.cancel();
    setState(() {
      _selectedPresetId = preset.id;
      _totalSeconds = preset.durationSeconds;
      _remaining = preset.durationSeconds;
      _isRunning = false;
    });
  }

  void _startPause() {
    if (_isAlarmPlaying) {
      _stopAlarm();
      setState(() {});
      return;
    }
    if (_isRunning) {
      _timer?.cancel();
      _stopAmbient();
      widget.timerService.cancelTimerAlarm();
      setState(() => _isRunning = false);
    } else {
      if (_remaining <= 0) _remaining = _totalSeconds;
      widget.timerService.scheduleTimerAlarm(_remaining, '카운트다운');
      _startAmbient();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _remaining--;
          if (_remaining <= 0) {
            _remaining = 0;
            _isRunning = false;
            _timer?.cancel();
            _stopAmbient();
            widget.timerService.cancelTimerAlarm();
            _playAlarm();
            widget.timerService.notifyTimerComplete('카운트다운');
          }
        });
      });
      setState(() => _isRunning = true);
    }
  }

  void _reset() {
    _timer?.cancel();
    _stopAlarm();
    _stopAmbient();
    widget.timerService.cancelTimerAlarm();
    setState(() {
      _remaining = _totalSeconds;
      _isRunning = false;
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final presets = widget.timerService.getAll().where((p) => !p.isPomodoro).toList();
    final progress = _totalSeconds > 0 ? _remaining / _totalSeconds : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final circleSize = (constraints.maxWidth * 0.5).clamp(160.0, 220.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                // Circular progress
                SizedBox(
                  width: circleSize,
                  height: circleSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: circleSize,
                        height: circleSize,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      Text(
                        _formatTime(_remaining > 0 ? _remaining : _totalSeconds),
                        style: TextStyle(fontSize: circleSize * 0.2, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _startPause,
                      icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(_isRunning ? '일시정지' : '시작'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('리셋'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Ambient sound controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _AmbientSoundControls(
                    selectedSound: _ambientSound,
                    volume: _ambientVolume,
                    onSoundChanged: _onAmbientChanged,
                    onVolumeChanged: _onAmbientVolumeChanged,
                  ),
                ),
                const SizedBox(height: 20),
                // Presets
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ...presets.map((p) => GestureDetector(
                            onLongPress: () async {
                              if (p.id.startsWith('default_')) return;
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('프리셋 삭제'),
                                  content: Text('"${p.label}" 프리셋을 삭제할까요?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await widget.timerService.delete(p.id);
                                setState(() {});
                              }
                            },
                            child: ChoiceChip(
                              label: Text(p.label),
                              selected: _selectedPresetId == p.id,
                              onSelected: (_) => _selectPreset(p),
                            ),
                          )),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('추가'),
                        onPressed: _addPreset,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPreset() async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('커스텀 프리셋'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '시간 (분)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              final mins = int.tryParse(controller.text);
              if (mins != null && mins > 0) Navigator.pop(context, mins);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await widget.timerService.add(TimerPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: '${result}분',
      durationSeconds: result * 60,
    ));
    setState(() {});
  }
}

// ─── Pomodoro Tab ──────────────────────────────────────

class _PomodoroTab extends StatefulWidget {
  final TimerService timerService;
  const _PomodoroTab({required this.timerService});

  @override
  State<_PomodoroTab> createState() => _PomodoroTabState();
}

class _PomodoroTabState extends State<_PomodoroTab> {
  static const _audioChannel = MethodChannel('com.aicharacter.ai_character/audio');

  Timer? _timer;
  int _focusMinutes = 25;
  int _breakMinutes = 5;
  int _targetSessions = 4;
  int _currentSession = 1;
  bool _isFocusPhase = true;
  int _remaining = 0;
  bool _isRunning = false;
  bool _isAlarmPlaying = false;

  // Ambient sound
  AmbientSound _ambientSound = AmbientSound.none;
  double _ambientVolume = 0.5;

  @override
  void initState() {
    super.initState();
    _remaining = _focusMinutes * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAlarm();
    _stopAmbient();
    super.dispose();
  }

  void _playAlarm() {
    _isAlarmPlaying = true;
    _audioChannel.invokeMethod('playAlarm');
  }

  void _stopAlarm() {
    if (_isAlarmPlaying) {
      _isAlarmPlaying = false;
      _audioChannel.invokeMethod('stopAlarm');
    }
  }

  void _startAmbient() {
    if (_ambientSound != AmbientSound.none) {
      _audioChannel.invokeMethod('startAmbient', {
        'type': _ambientSound.typeKey,
        'volume': _ambientVolume,
      });
    }
  }

  void _stopAmbient() {
    _audioChannel.invokeMethod('stopAmbient');
  }

  void _onAmbientChanged(AmbientSound sound) {
    setState(() => _ambientSound = sound);
    if (sound == AmbientSound.none) {
      _stopAmbient();
    } else if (_isRunning) {
      _audioChannel.invokeMethod('startAmbient', {
        'type': sound.typeKey,
        'volume': _ambientVolume,
      });
    }
  }

  void _onAmbientVolumeChanged(double vol) {
    setState(() => _ambientVolume = vol);
    if (_ambientSound != AmbientSound.none && _isRunning) {
      _audioChannel.invokeMethod('setAmbientVolume', {'volume': vol});
    }
  }

  int get _totalPhaseSeconds => (_isFocusPhase ? _focusMinutes : _breakMinutes) * 60;

  void _startPause() {
    if (_isAlarmPlaying) {
      _stopAlarm();
      setState(() {});
      return;
    }
    if (_isRunning) {
      _timer?.cancel();
      _stopAmbient();
      widget.timerService.cancelTimerAlarm();
      setState(() => _isRunning = false);
    } else {
      if (_remaining <= 0) _remaining = _totalPhaseSeconds;
      final phaseLabel = _isFocusPhase ? '뽀모도로 집중' : '뽀모도로 휴식';
      widget.timerService.scheduleTimerAlarm(_remaining, phaseLabel);
      _startAmbient();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _remaining--;
          if (_remaining <= 0) {
            _remaining = 0;
            _timer?.cancel();
            _isRunning = false;
            _stopAmbient();
            widget.timerService.cancelTimerAlarm();
            _onPhaseComplete();
          }
        });
      });
      setState(() => _isRunning = true);
    }
  }

  void _onPhaseComplete() {
    _playAlarm();
    if (_isFocusPhase) {
      if (_currentSession >= _targetSessions) {
        widget.timerService.notifyTimerComplete('뽀모도로 $_targetSessions세션 완료!');
        setState(() {
          _currentSession = 1;
          _isFocusPhase = true;
          _remaining = _focusMinutes * 60;
        });
        return;
      }
      setState(() {
        _isFocusPhase = false;
        _remaining = _breakMinutes * 60;
      });
      widget.timerService.notifyPomodoroPhase(isFocus: false, session: _currentSession, total: _targetSessions);
    } else {
      setState(() {
        _currentSession++;
        _isFocusPhase = true;
        _remaining = _focusMinutes * 60;
      });
      widget.timerService.notifyPomodoroPhase(isFocus: true, session: _currentSession, total: _targetSessions);
    }
  }

  void _reset() {
    _timer?.cancel();
    _stopAlarm();
    _stopAmbient();
    widget.timerService.cancelTimerAlarm();
    setState(() {
      _currentSession = 1;
      _isFocusPhase = true;
      _remaining = _focusMinutes * 60;
      _isRunning = false;
    });
  }

  Future<void> _enterFocusMode() async {
    _timer?.cancel();
    _stopAmbient();
    final wasRunning = _isRunning;
    setState(() => _isRunning = false);

    final result = await Navigator.push<_PomodoroState>(
      context,
      MaterialPageRoute(
        builder: (_) => _FocusModeScreen(
          timerService: widget.timerService,
          state: _PomodoroState(
            focusMinutes: _focusMinutes,
            breakMinutes: _breakMinutes,
            targetSessions: _targetSessions,
            currentSession: _currentSession,
            isFocusPhase: _isFocusPhase,
            remaining: _remaining,
            wasRunning: wasRunning,
            ambientSound: _ambientSound,
            ambientVolume: _ambientVolume,
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _focusMinutes = result.focusMinutes;
        _breakMinutes = result.breakMinutes;
        _targetSessions = result.targetSessions;
        _currentSession = result.currentSession;
        _isFocusPhase = result.isFocusPhase;
        _remaining = result.remaining;
        _ambientSound = result.ambientSound;
        _ambientVolume = result.ambientVolume;
        _isRunning = false;
      });
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _totalPhaseSeconds > 0 ? _remaining / _totalPhaseSeconds : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final circleSize = (constraints.maxWidth * 0.5).clamp(160.0, 220.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                // Phase label
                Text(
                  _isFocusPhase ? '집중' : '휴식',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _isFocusPhase ? theme.colorScheme.primary : AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_currentSession/$_targetSessions 세션',
                  style: TextStyle(fontSize: 14, color: AppColors.grey600),
                ),
                const SizedBox(height: 20),
                // Circular progress
                SizedBox(
                  width: circleSize,
                  height: circleSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: circleSize,
                        height: circleSize,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          color: _isFocusPhase ? theme.colorScheme.primary : AppColors.success,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      Text(
                        _formatTime(_remaining),
                        style: TextStyle(fontSize: circleSize * 0.2, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _startPause,
                      icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(_isRunning ? '일시정지' : '시작'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('리셋'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Focus mode button
                TextButton.icon(
                  onPressed: _enterFocusMode,
                  icon: const Icon(Icons.fullscreen, size: 20),
                  label: const Text('집중모드'),
                ),
                const SizedBox(height: 8),
                // Ambient sound controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _AmbientSoundControls(
                    selectedSound: _ambientSound,
                    volume: _ambientVolume,
                    onSoundChanged: _onAmbientChanged,
                    onVolumeChanged: _onAmbientVolumeChanged,
                  ),
                ),
                const SizedBox(height: 12),
                // Settings - compact layout
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        _CompactSetting(
                          label: '집중(분)',
                          value: _focusMinutes,
                          enabled: !_isRunning,
                          onChanged: (v) {
                            setState(() {
                              _focusMinutes = v;
                              if (_isFocusPhase) _remaining = v * 60;
                            });
                          },
                        ),
                        Container(width: 1, height: 36, color: AppColors.grey300),
                        _CompactSetting(
                          label: '휴식(분)',
                          value: _breakMinutes,
                          enabled: !_isRunning,
                          onChanged: (v) {
                            setState(() {
                              _breakMinutes = v;
                              if (!_isFocusPhase) _remaining = v * 60;
                            });
                          },
                        ),
                        Container(width: 1, height: 36, color: AppColors.grey300),
                        _CompactSetting(
                          label: '세션',
                          value: _targetSessions,
                          min: 1,
                          max: 10,
                          enabled: !_isRunning,
                          onChanged: (v) => setState(() => _targetSessions = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Pomodoro State Transfer ──────────────────────────

class _PomodoroState {
  final int focusMinutes;
  final int breakMinutes;
  final int targetSessions;
  int currentSession;
  bool isFocusPhase;
  int remaining;
  final bool wasRunning;
  AmbientSound ambientSound;
  double ambientVolume;

  _PomodoroState({
    required this.focusMinutes,
    required this.breakMinutes,
    required this.targetSessions,
    required this.currentSession,
    required this.isFocusPhase,
    required this.remaining,
    this.wasRunning = false,
    this.ambientSound = AmbientSound.none,
    this.ambientVolume = 0.5,
  });
}

// ─── Focus Mode Screen ────────────────────────────────

class _FocusModeScreen extends StatefulWidget {
  final TimerService timerService;
  final _PomodoroState state;

  const _FocusModeScreen({required this.timerService, required this.state});

  @override
  State<_FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<_FocusModeScreen> {
  static const _audioChannel = MethodChannel('com.aicharacter.ai_character/audio');

  late _PomodoroState _s;
  Timer? _timer;
  bool _isRunning = false;
  bool _isAlarmPlaying = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _s = widget.state;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (_s.wasRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startPause());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAlarm();
    _stopAmbient();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _playAlarm() {
    _isAlarmPlaying = true;
    _audioChannel.invokeMethod('playAlarm');
  }

  void _stopAlarm() {
    if (_isAlarmPlaying) {
      _isAlarmPlaying = false;
      _audioChannel.invokeMethod('stopAlarm');
    }
  }

  void _startAmbient() {
    if (_s.ambientSound != AmbientSound.none) {
      _audioChannel.invokeMethod('startAmbient', {
        'type': _s.ambientSound.typeKey,
        'volume': _s.ambientVolume,
      });
    }
  }

  void _stopAmbient() {
    _audioChannel.invokeMethod('stopAmbient');
  }

  void _onAmbientChanged(AmbientSound sound) {
    setState(() => _s.ambientSound = sound);
    if (sound == AmbientSound.none) {
      _stopAmbient();
    } else if (_isRunning) {
      _audioChannel.invokeMethod('startAmbient', {
        'type': sound.typeKey,
        'volume': _s.ambientVolume,
      });
    }
  }

  void _onAmbientVolumeChanged(double vol) {
    setState(() => _s.ambientVolume = vol);
    if (_s.ambientSound != AmbientSound.none && _isRunning) {
      _audioChannel.invokeMethod('setAmbientVolume', {'volume': vol});
    }
  }

  int get _totalPhaseSeconds => (_s.isFocusPhase ? _s.focusMinutes : _s.breakMinutes) * 60;

  void _startPause() {
    if (_isAlarmPlaying) {
      _stopAlarm();
      setState(() {});
      return;
    }
    if (_isRunning) {
      _timer?.cancel();
      _stopAmbient();
      widget.timerService.cancelTimerAlarm();
      setState(() => _isRunning = false);
    } else {
      if (_s.remaining <= 0) _s.remaining = _totalPhaseSeconds;
      final phaseLabel = _s.isFocusPhase ? '뽀모도로 집중' : '뽀모도로 휴식';
      widget.timerService.scheduleTimerAlarm(_s.remaining, phaseLabel);
      _startAmbient();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _s.remaining--;
          if (_s.remaining <= 0) {
            _s.remaining = 0;
            _timer?.cancel();
            _isRunning = false;
            _stopAmbient();
            widget.timerService.cancelTimerAlarm();
            _onPhaseComplete();
          }
        });
      });
      setState(() => _isRunning = true);
    }
  }

  void _onPhaseComplete() {
    _playAlarm();
    if (_s.isFocusPhase) {
      if (_s.currentSession >= _s.targetSessions) {
        widget.timerService.notifyTimerComplete('뽀모도로 ${_s.targetSessions}세션 완료!');
        setState(() {
          _s.currentSession = 1;
          _s.isFocusPhase = true;
          _s.remaining = _s.focusMinutes * 60;
        });
        return;
      }
      setState(() {
        _s.isFocusPhase = false;
        _s.remaining = _s.breakMinutes * 60;
      });
      widget.timerService.notifyPomodoroPhase(isFocus: false, session: _s.currentSession, total: _s.targetSessions);
    } else {
      setState(() {
        _s.currentSession++;
        _s.isFocusPhase = true;
        _s.remaining = _s.focusMinutes * 60;
      });
      widget.timerService.notifyPomodoroPhase(isFocus: true, session: _s.currentSession, total: _s.targetSessions);
    }
  }

  void _exit() {
    _timer?.cancel();
    _stopAmbient();
    if (!_isRunning) {
      widget.timerService.cancelTimerAlarm();
    }
    _isRunning = false;
    Navigator.pop(context, _s);
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _totalPhaseSeconds > 0 ? _s.remaining / _totalPhaseSeconds : 0.0;
    final isFocus = _s.isFocusPhase;
    final accentColor = isFocus ? theme.colorScheme.primary : AppColors.success;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: GestureDetector(
          onTap: _startPause,
          onDoubleTap: () => setState(() => _showControls = !_showControls),
          child: Stack(
            children: [
              // Main content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Phase
                    Text(
                      isFocus ? '집중' : '휴식',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Timer circle
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              color: accentColor,
                              backgroundColor: AppColors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          Text(
                            _formatTime(_s.remaining),
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w200,
                              color: AppColors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Session
                    Text(
                      '${_s.currentSession} / ${_s.targetSessions}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Ambient sound controls (toggle with double tap)
                    if (_showControls)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _AmbientSoundControls(
                          selectedSound: _s.ambientSound,
                          volume: _s.ambientVolume,
                          onSoundChanged: _onAmbientChanged,
                          onVolumeChanged: _onAmbientVolumeChanged,
                          darkMode: true,
                        ),
                      )
                    else ...[
                      // Play/Pause hint
                      Icon(
                        _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 36,
                        color: AppColors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRunning ? '탭하여 일시정지' : '탭하여 시작',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      if (_s.ambientSound != AmbientSound.none)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _s.ambientSound.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              // Exit button
              Positioned(
                top: MediaQuery.of(context).viewPadding.top + 12,
                right: 12,
                child: IconButton(
                  onPressed: _exit,
                  icon: Icon(
                    Icons.close,
                    color: AppColors.white.withValues(alpha: 0.4),
                    size: 24,
                  ),
                ),
              ),
              // Sound toggle hint
              if (!_showControls)
                Positioned(
                  bottom: MediaQuery.of(context).viewPadding.bottom + 16,
                  left: 0,
                  right: 0,
                  child: Text(
                    '더블탭으로 배경음 설정',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Compact Setting Widget ───────────────────────────

class _CompactSetting extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _CompactSetting({
    required this.label,
    required this.value,
    this.min = 1,
    this.max = 60,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.grey600)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.remove),
                  onPressed: enabled && value > min ? () => onChanged(value - 1) : null,
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.add),
                  onPressed: enabled && value < max ? () => onChanged(value + 1) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
