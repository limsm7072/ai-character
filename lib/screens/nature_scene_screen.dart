import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/nature_scene.dart';

class NatureSceneScreen extends StatefulWidget {
  const NatureSceneScreen({super.key});

  @override
  State<NatureSceneScreen> createState() => _NatureSceneScreenState();
}

class _NatureSceneScreenState extends State<NatureSceneScreen>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('com.aicharacter.ai_character/audio');

  int _selectedIndex = 0;
  double _volume = 0.7;
  bool _playing = false;
  int? _timerMinutes;
  Timer? _timer;
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
    _iconAnim.dispose();
    super.dispose();
  }

  Future<void> _startSound() async {
    try {
      await _channel.invokeMethod('startAmbient', {
        'type': _current.soundType,
        'volume': _volume,
      });
      if (mounted) setState(() => _playing = true);
    } catch (_) {}
  }

  Future<void> _stopSound() async {
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
    setState(() => _selectedIndex = index);
    try {
      await _channel.invokeMethod('startAmbient', {
        'type': _current.soundType,
        'volume': _volume,
      });
      if (mounted) setState(() => _playing = true);
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
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Scene icon with breathing animation
              AnimatedBuilder(
                animation: _iconAnim,
                builder: (_, __) {
                  final scale = 1.0 + _iconAnim.value * 0.08;
                  final opacity = 0.6 + _iconAnim.value * 0.4;
                  return Transform.scale(
                    scale: scale,
                    child: Icon(
                      scene.icon,
                      size: 80,
                      color: Colors.white.withValues(alpha: opacity),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                scene.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              if (_timerMinutes != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formatRemaining(),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const Spacer(flex: 3),
              // Volume slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    Icon(Icons.volume_down, color: Colors.white.withValues(alpha: 0.7), size: 20),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: Colors.white.withValues(alpha: 0.8),
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withValues(alpha: 0.1),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        ),
                        child: Slider(
                          value: _volume,
                          onChanged: _setVolume,
                        ),
                      ),
                    ),
                    Icon(Icons.volume_up, color: Colors.white.withValues(alpha: 0.7), size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Play/Pause + Timer buttons
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
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: IconButton(
                      iconSize: 36,
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
                  const SizedBox(width: 48), // balance
                ],
              ),
              const SizedBox(height: 24),
              // Scene selector chips
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: NatureScene.scenes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final s = NatureScene.scenes[i];
                    final selected = i == _selectedIndex;
                    return GestureDetector(
                      onTap: () => _selectScene(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: selected
                              ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(s.icon, size: 24, color: Colors.white.withValues(alpha: selected ? 1.0 : 0.6)),
                            const SizedBox(height: 4),
                            Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 11,
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

