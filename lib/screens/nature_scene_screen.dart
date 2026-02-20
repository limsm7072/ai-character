import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/nature_scene.dart';
import 'nature_focus_screen.dart';

class NatureSceneScreen extends StatefulWidget {
  const NatureSceneScreen({super.key});

  @override
  State<NatureSceneScreen> createState() => _NatureSceneScreenState();
}

class _NatureSceneScreenState extends State<NatureSceneScreen>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('com.aicharacter.ai_character/audio');

  int _selectedIndex = 0;
  double _volume = 0.1;
  bool _playing = false;
  int? _timerMinutes;
  Timer? _timer;
  Timer? _fadeTimer;
  int _remainingSeconds = 0;
  late AnimationController _iconAnim;

  NatureScene get _current => NatureScene.scenes[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _iconAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _startSound();
  }

  @override
  void dispose() {
    _stopSound();
    _timer?.cancel();
    _fadeTimer?.cancel();
    _iconAnim.dispose();
    super.dispose();
  }

  Future<void> _startSound() async {
    _fadeTimer?.cancel();
    try {
      // Start at volume 0 then fade in
      await _channel.invokeMethod('startAmbient', {
        'type': _current.soundType,
        'volume': 0.0,
      });
      if (mounted) setState(() => _playing = true);
      // Fade in over 2 seconds (40 steps × 50ms)
      var step = 0;
      const totalSteps = 40;
      _fadeTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
        step++;
        if (step >= totalSteps) {
          t.cancel();
          _channel.invokeMethod('setAmbientVolume', {'volume': _volume});
          return;
        }
        final vol = _volume * (step / totalSteps);
        _channel.invokeMethod('setAmbientVolume', {'volume': vol});
      });
    } catch (_) {}
  }

  Future<void> _stopSound() async {
    _fadeTimer?.cancel();
    try {
      await _channel.invokeMethod('stopAmbient');
      if (mounted) setState(() => _playing = false);
    } catch (_) {}
  }

  Future<void> _setVolume(double vol) async {
    setState(() => _volume = vol);
    try {
      await _channel.invokeMethod('setAmbientVolume', {'volume': vol});
    } catch (_) {}
  }

  void _selectScene(int index) async {
    if (index == _selectedIndex) return;
    _fadeTimer?.cancel();
    setState(() => _selectedIndex = index);
    try {
      await _channel.invokeMethod('startAmbient', {
        'type': _current.soundType,
        'volume': 0.0,
      });
      if (mounted) setState(() => _playing = true);
      // Fade in
      var step = 0;
      const totalSteps = 40;
      _fadeTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
        step++;
        if (step >= totalSteps) {
          t.cancel();
          _channel.invokeMethod('setAmbientVolume', {'volume': _volume});
          return;
        }
        final vol = _volume * (step / totalSteps);
        _channel.invokeMethod('setAmbientVolume', {'volume': vol});
      });
    } catch (_) {}
  }

  void _showTimerPicker() {
    final options = [null, 5, 10, 15, 30, 60];
    final labels = ['끄기', '5분', '10분', '15분', '30분', '1시간'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('타이머', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ...List.generate(options.length, (i) {
                  final selected = _timerMinutes == options[i];
                  return ListTile(
                    title: Text(labels[i]),
                    trailing: selected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _setTimer(options[i]);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setTimer(int? minutes) {
    _timer?.cancel();
    setState(() {
      _timerMinutes = minutes;
      if (minutes == null) {
        _remainingSeconds = 0;
        return;
      }
      _remainingSeconds = minutes * 60;
    });
    if (minutes != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_remainingSeconds <= 1) {
          t.cancel();
          _stopSound();
          if (mounted) {
            setState(() {
              _timerMinutes = null;
              _remainingSeconds = 0;
            });
          }
          return;
        }
        if (mounted) setState(() => _remainingSeconds--);
      });
    }
  }

  String _formatRemaining() {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _openFocusMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NatureFocusScreen(
          scene: _current,
          volume: _volume,
          remainingSeconds: _timerMinutes != null ? _remainingSeconds : null,
          onVolumeChanged: (v) => _setVolume(v),
        ),
      ),
    ).then((_) {
      // Restore system UI when returning
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scene = _current;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: scene.gradient,
          ),
        ),
        child: SafeArea(
          top: true,
          bottom: true,
          child: Column(
            children: [
              // Center content (flexible)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _iconAnim,
                        builder: (_, __) {
                          final scale = 1.0 + _iconAnim.value * 0.08;
                          final opacity = 0.6 + _iconAnim.value * 0.4;
                          return Transform.scale(
                            scale: scale,
                            child: Icon(
                              scene.icon,
                              size: 64,
                              color: Colors.white.withValues(alpha: opacity),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        scene.name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      if (_timerMinutes != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _formatRemaining(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Bottom controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    Icon(Icons.volume_down, color: Colors.white.withValues(alpha: 0.7), size: 18),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: Colors.white.withValues(alpha: 0.8),
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withValues(alpha: 0.1),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: _volume,
                          onChanged: _setVolume,
                        ),
                      ),
                    ),
                    Icon(Icons.volume_up, color: Colors.white.withValues(alpha: 0.7), size: 18),
                  ],
                ),
              ),
              // Play/Pause + Timer + Focus buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _showTimerPicker,
                    icon: Icon(
                      Icons.timer_outlined,
                      color: _timerMinutes != null
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                      size: 24,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: IconButton(
                      iconSize: 32,
                      padding: const EdgeInsets.all(10),
                      onPressed: () {
                        if (_playing) {
                          _stopSound();
                        } else {
                          _startSound();
                        }
                      },
                      icon: Icon(
                        _playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _playing ? _openFocusMode : null,
                    icon: Icon(
                      Icons.self_improvement,
                      color: _playing
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                      size: 24,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    tooltip: '집중모드',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Scene selector chips
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: NatureScene.scenes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final s = NatureScene.scenes[i];
                    final selected = i == _selectedIndex;
                    return GestureDetector(
                      onTap: () => _selectScene(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 54,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: selected
                              ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(s.icon, size: 20, color: Colors.white.withValues(alpha: selected ? 1.0 : 0.6)),
                            const SizedBox(height: 2),
                            Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: selected ? 1.0 : 0.6),
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
