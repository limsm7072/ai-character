import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/nature_scene.dart';
import '../theme/app_colors.dart';

class NatureFocusScreen extends StatefulWidget {
  final NatureScene scene;
  final double volume;
  final int? remainingSeconds;
  final ValueChanged<double>? onVolumeChanged;

  const NatureFocusScreen({
    super.key,
    required this.scene,
    required this.volume,
    this.remainingSeconds,
    this.onVolumeChanged,
  });

  @override
  State<NatureFocusScreen> createState() => _NatureFocusScreenState();
}

class _NatureFocusScreenState extends State<NatureFocusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late double _volume;
  int _remaining = 0;
  Timer? _countdownTimer;
  bool _showUI = true;
  Timer? _hideTimer;
  final _random = Random();
  late List<_Particle> _particles;
  // For ocean waves
  double _wavePhase = 0;

  @override
  void initState() {
    super.initState();
    _volume = widget.volume;
    _remaining = widget.remainingSeconds ?? 0;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_tick);
    _animController.repeat();

    _particles = _generateParticles();

    if (_remaining > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remaining <= 1) {
          _countdownTimer?.cancel();
          setState(() => _remaining = 0);
          return;
        }
        setState(() => _remaining--);
      });
    }

    _scheduleHide();
  }

  @override
  void dispose() {
    _animController.dispose();
    _countdownTimer?.cancel();
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showUI = false);
    });
  }

  void _onTap() {
    setState(() => _showUI = !_showUI);
    if (_showUI) _scheduleHide();
  }

  void _tick() {
    if (!mounted) return;
    _updateParticles();
    _wavePhase += 0.02;
    setState(() {});
  }

  // ─── Particle system ───────────────────────────────

  List<_Particle> _generateParticles() {
    final type = widget.scene.soundType;
    switch (type) {
      case 'rain':
        return List.generate(120, (_) => _makeRainDrop());
      case 'ocean':
        return []; // ocean uses wave lines, not particles
      case 'stream':
        return List.generate(60, (_) => _makeStreamDrop());
      case 'forest':
        return [
          ...List.generate(15, (_) => _makeLeaf()),
          ...List.generate(20, (_) => _makeFirefly()),
        ];
      case 'fire':
        return List.generate(50, (_) => _makeEmber());
      case 'wind':
        return List.generate(40, (_) => _makeWindLine());
      case 'night':
        return [
          ...List.generate(60, (_) => _makeStar()),
          ...List.generate(2, (_) => _makeMeteor()),
        ];
      default:
        return [];
    }
  }

  // Rain
  _Particle _makeRainDrop() => _Particle(
    x: _random.nextDouble(),
    y: _random.nextDouble(),
    speed: 0.008 + _random.nextDouble() * 0.012,
    size: 1.0 + _random.nextDouble() * 1.5,
    opacity: 0.2 + _random.nextDouble() * 0.4,
    length: 15.0 + _random.nextDouble() * 25.0,
  );

  // Stream
  _Particle _makeStreamDrop() => _Particle(
    x: _random.nextDouble(),
    y: 0.3 + _random.nextDouble() * 0.5,
    speed: 0.002 + _random.nextDouble() * 0.004,
    size: 2.0 + _random.nextDouble() * 3.0,
    opacity: 0.15 + _random.nextDouble() * 0.3,
  );

  // Forest - leaf
  _Particle _makeLeaf() => _Particle(
    x: _random.nextDouble(),
    y: _random.nextDouble(),
    speed: 0.0005 + _random.nextDouble() * 0.001,
    size: 4.0 + _random.nextDouble() * 6.0,
    opacity: 0.3 + _random.nextDouble() * 0.4,
    angle: _random.nextDouble() * pi * 2,
    extra: 0, // type=leaf
  );

  // Forest - firefly
  _Particle _makeFirefly() => _Particle(
    x: _random.nextDouble(),
    y: 0.3 + _random.nextDouble() * 0.6,
    speed: 0.0003 + _random.nextDouble() * 0.0005,
    size: 2.0 + _random.nextDouble() * 2.0,
    opacity: _random.nextDouble(),
    angle: _random.nextDouble() * pi * 2,
    extra: 1, // type=firefly
  );

  // Fire - ember
  _Particle _makeEmber() => _Particle(
    x: 0.2 + _random.nextDouble() * 0.6,
    y: 0.8 + _random.nextDouble() * 0.2,
    speed: 0.001 + _random.nextDouble() * 0.003,
    size: 2.0 + _random.nextDouble() * 4.0,
    opacity: 0.5 + _random.nextDouble() * 0.5,
    angle: -pi / 2 + (_random.nextDouble() - 0.5) * 0.6,
  );

  // Wind
  _Particle _makeWindLine() => _Particle(
    x: _random.nextDouble(),
    y: _random.nextDouble(),
    speed: 0.003 + _random.nextDouble() * 0.006,
    size: 1.0,
    opacity: 0.1 + _random.nextDouble() * 0.2,
    length: 20.0 + _random.nextDouble() * 40.0,
  );

  // Night - star
  _Particle _makeStar() => _Particle(
    x: _random.nextDouble(),
    y: _random.nextDouble() * 0.7,
    speed: 0.5 + _random.nextDouble() * 2.0, // twinkle speed
    size: 1.0 + _random.nextDouble() * 2.0,
    opacity: 0.3 + _random.nextDouble() * 0.7,
    extra: 0, // type=star
  );

  // Night - meteor
  _Particle _makeMeteor() => _Particle(
    x: _random.nextDouble(),
    y: _random.nextDouble() * 0.3,
    speed: 0.01 + _random.nextDouble() * 0.005,
    size: 1.5,
    opacity: 0.0,
    length: 30.0 + _random.nextDouble() * 50.0,
    angle: pi / 4 + (_random.nextDouble() - 0.5) * 0.3,
    extra: 1, // type=meteor
  );

  void _updateParticles() {
    final type = widget.scene.soundType;
    switch (type) {
      case 'rain':
        for (final p in _particles) {
          p.y += p.speed;
          p.x += p.speed * 0.1; // slight wind
          if (p.y > 1.1) {
            p.y = -0.05;
            p.x = _random.nextDouble();
            p.opacity = 0.2 + _random.nextDouble() * 0.4;
          }
        }
        break;
      case 'stream':
        for (final p in _particles) {
          p.x += p.speed;
          p.y += sin(p.x * 20) * 0.0003;
          if (p.x > 1.1) {
            p.x = -0.05;
            p.y = 0.3 + _random.nextDouble() * 0.5;
          }
        }
        break;
      case 'forest':
        for (final p in _particles) {
          if (p.extra == 0) {
            // leaf
            p.y += p.speed;
            p.x += sin(p.angle + _wavePhase * 2) * 0.001;
            p.angle += 0.02;
            if (p.y > 1.05) {
              p.y = -0.05;
              p.x = _random.nextDouble();
            }
          } else {
            // firefly
            p.x += sin(p.angle + _wavePhase * 3) * 0.001;
            p.y += cos(p.angle + _wavePhase * 2) * 0.0005;
            p.opacity = 0.2 + sin(_wavePhase * p.speed * 200 + p.angle) * 0.5;
            p.opacity = p.opacity.clamp(0.0, 1.0);
          }
        }
        break;
      case 'fire':
        for (final p in _particles) {
          p.y -= p.speed;
          p.x += sin(p.angle + _wavePhase * 3) * 0.002;
          p.opacity -= 0.003;
          p.size *= 0.999;
          if (p.opacity <= 0 || p.y < 0.1) {
            p.x = 0.2 + _random.nextDouble() * 0.6;
            p.y = 0.8 + _random.nextDouble() * 0.2;
            p.opacity = 0.5 + _random.nextDouble() * 0.5;
            p.size = 2.0 + _random.nextDouble() * 4.0;
            p.speed = 0.001 + _random.nextDouble() * 0.003;
          }
        }
        break;
      case 'wind':
        for (final p in _particles) {
          p.x += p.speed;
          p.y += sin(p.x * 10 + _wavePhase) * 0.0005;
          if (p.x > 1.2) {
            p.x = -0.15;
            p.y = _random.nextDouble();
            p.speed = 0.003 + _random.nextDouble() * 0.006;
          }
        }
        break;
      case 'night':
        for (final p in _particles) {
          if (p.extra == 0) {
            // star twinkle
            p.opacity = 0.3 + sin(_wavePhase * p.speed + p.x * 10) * 0.4;
            p.opacity = p.opacity.clamp(0.1, 1.0);
          } else {
            // meteor
            if (p.opacity > 0) {
              p.x += cos(p.angle) * p.speed;
              p.y += sin(p.angle) * p.speed;
              p.opacity -= 0.008;
              if (p.x > 1.2 || p.y > 1.0 || p.opacity <= 0) {
                p.opacity = 0;
              }
            } else {
              // random chance to reappear
              if (_random.nextDouble() < 0.001) {
                p.x = _random.nextDouble() * 0.5;
                p.y = _random.nextDouble() * 0.2;
                p.opacity = 0.8;
                p.angle = pi / 4 + (_random.nextDouble() - 0.5) * 0.3;
              }
            }
          }
        }
        break;
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    return Scaffold(
      body: GestureDetector(
        onTap: _onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: scene.gradient,
                ),
              ),
            ),
            // Particle layer
            CustomPaint(
              painter: _NatureParticlePainter(
                type: scene.soundType,
                particles: _particles,
                wavePhase: _wavePhase,
              ),
              size: Size.infinite,
            ),
            // UI overlay (auto-hide)
            AnimatedOpacity(
              opacity: _showUI ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: IgnorePointer(
                ignoring: !_showUI,
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                            const Spacer(),
                            Text(
                              '집중모드',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Center info
                      Icon(
                        scene.icon,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        scene.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 2,
                        ),
                      ),
                      if (_remaining > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          _formatTime(_remaining),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w200,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Volume slider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 50),
                        child: Row(
                          children: [
                            Icon(Icons.volume_down, color: Colors.white.withValues(alpha: 0.5), size: 18),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: Colors.white.withValues(alpha: 0.6),
                                  inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                                  thumbColor: Colors.white.withValues(alpha: 0.8),
                                  overlayColor: Colors.white.withValues(alpha: 0.05),
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: _volume,
                                  onChanged: (v) {
                                    setState(() => _volume = v);
                                    widget.onVolumeChanged?.call(v);
                                    _scheduleHide();
                                  },
                                ),
                              ),
                            ),
                            Icon(Icons.volume_up, color: Colors.white.withValues(alpha: 0.5), size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Particle data ────────────────────────────────

class _Particle {
  double x, y, speed, size, opacity;
  double angle;
  double length;
  int extra; // sub-type flag

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    this.angle = 0,
    this.length = 0,
    this.extra = 0,
  });
}

// ─── Particle painter ─────────────────────────────

class _NatureParticlePainter extends CustomPainter {
  final String type;
  final List<_Particle> particles;
  final double wavePhase;

  _NatureParticlePainter({
    required this.type,
    required this.particles,
    required this.wavePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case 'rain':
        _paintRain(canvas, size);
        break;
      case 'ocean':
        _paintOcean(canvas, size);
        break;
      case 'stream':
        _paintStream(canvas, size);
        break;
      case 'forest':
        _paintForest(canvas, size);
        break;
      case 'fire':
        _paintFire(canvas, size);
        break;
      case 'wind':
        _paintWind(canvas, size);
        break;
      case 'night':
        _paintNight(canvas, size);
        break;
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final p in particles) {
      paint.color = Colors.white.withValues(alpha: p.opacity);
      paint.strokeWidth = p.size;
      final x = p.x * size.width;
      final y = p.y * size.height;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 2, y + p.length),
        paint,
      );
    }
  }

  void _paintOcean(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int layer = 0; layer < 4; layer++) {
      final yBase = size.height * (0.45 + layer * 0.12);
      final alpha = 0.15 - layer * 0.03;
      paint.color = Colors.white.withValues(alpha: alpha.clamp(0.05, 0.2));
      final path = Path();
      for (double x = 0; x <= size.width; x += 3) {
        final y = yBase +
            sin((x / size.width) * pi * 3 + wavePhase * (1.5 + layer * 0.3)) * (15 + layer * 5) +
            sin((x / size.width) * pi * 5 + wavePhase * 0.7) * 8;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintStream(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    // Flow lines
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < 3; i++) {
      final yBase = size.height * (0.4 + i * 0.15);
      linePaint.color = AppColors.infoLight.withValues(alpha: 0.08);
      final path = Path();
      for (double x = 0; x <= size.width; x += 4) {
        final y = yBase + sin((x / size.width) * pi * 4 + wavePhase * (2 + i * 0.5)) * 10;
        if (x == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      canvas.drawPath(path, linePaint);
    }
    // Drops
    for (final p in particles) {
      paint.color = AppColors.infoLight.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  void _paintForest(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      if (p.extra == 0) {
        // Leaf
        paint.color = AppColors.success.withValues(alpha: p.opacity);
        canvas.save();
        canvas.translate(p.x * size.width, p.y * size.height);
        canvas.rotate(p.angle);
        final leafPath = Path()
          ..moveTo(0, -p.size)
          ..quadraticBezierTo(p.size * 0.8, 0, 0, p.size)
          ..quadraticBezierTo(-p.size * 0.8, 0, 0, -p.size);
        canvas.drawPath(leafPath, paint);
        canvas.restore();
      } else {
        // Firefly
        paint.color = AppColors.accentLight.withValues(alpha: p.opacity * 0.8);
        canvas.drawCircle(
          Offset(p.x * size.width, p.y * size.height),
          p.size,
          paint,
        );
        // Glow
        paint.color = AppColors.accentLight.withValues(alpha: p.opacity * 0.2);
        canvas.drawCircle(
          Offset(p.x * size.width, p.y * size.height),
          p.size * 3,
          paint,
        );
      }
    }
  }

  void _paintFire(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final color = Color.lerp(AppColors.error, AppColors.warning, p.y.clamp(0.0, 1.0))!;
      paint.color = color.withValues(alpha: p.opacity * 0.8);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
      // Glow
      paint.color = color.withValues(alpha: p.opacity * 0.15);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size * 2.5,
        paint,
      );
    }
    // Base fire glow
    final glowPaint = Paint()
      ..color = AppColors.warning.withValues(alpha: 0.05 + sin(wavePhase * 3) * 0.03);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.85),
      size.width * 0.3,
      glowPaint,
    );
  }

  void _paintWind(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round;
    for (final p in particles) {
      paint.color = Colors.white.withValues(alpha: p.opacity);
      paint.strokeWidth = p.size;
      final x = p.x * size.width;
      final y = p.y * size.height;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + p.length, y + sin(p.x * 5 + wavePhase) * 3),
        paint,
      );
    }
  }

  void _paintNight(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      if (p.extra == 0) {
        // Star
        paint.color = Colors.white.withValues(alpha: p.opacity);
        canvas.drawCircle(
          Offset(p.x * size.width, p.y * size.height),
          p.size,
          paint,
        );
        // Star glow
        if (p.size > 2) {
          paint.color = Colors.white.withValues(alpha: p.opacity * 0.2);
          canvas.drawCircle(
            Offset(p.x * size.width, p.y * size.height),
            p.size * 2,
            paint,
          );
        }
      } else {
        // Meteor
        if (p.opacity > 0) {
          paint.strokeWidth = p.size;
          paint.strokeCap = StrokeCap.round;
          paint.color = Colors.white.withValues(alpha: p.opacity);
          final x = p.x * size.width;
          final y = p.y * size.height;
          canvas.drawLine(
            Offset(x, y),
            Offset(
              x - cos(p.angle) * p.length,
              y - sin(p.angle) * p.length,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NatureParticlePainter old) => true;
}
