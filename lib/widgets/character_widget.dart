import 'package:flutter/material.dart';
import '../models/character_state.dart';

/// 2D placeholder character widget.
/// This will be replaced by flutter_unity_widget when Unity module is ready.
/// For now, renders a cute animated character using Flutter widgets.
class CharacterWidget extends StatefulWidget {
  final CharacterState state;
  final VoidCallback? onTap;

  const CharacterWidget({
    super.key,
    required this.state,
    this.onTap,
  });

  @override
  State<CharacterWidget> createState() => _CharacterWidgetState();
}

class _CharacterWidgetState extends State<CharacterWidget>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _gestureController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _gestureController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _bounceAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(CharacterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.emotion != widget.state.emotion ||
        oldWidget.state.gesture != widget.state.gesture) {
      _gestureController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _gestureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _bounceAnim,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _bounceAnim.value),
          child: child,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Character body
            _buildCharacter(),
            const SizedBox(height: 8),
            // Speech bubble
            if (widget.state.text.isNotEmpty)
              _buildSpeechBubble(widget.state.text),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacter() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _emotionColor(widget.state.emotion),
        boxShadow: [
          BoxShadow(
            color: _emotionColor(widget.state.emotion).withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Face
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Eyes
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEye(left: true),
                  const SizedBox(width: 16),
                  _buildEye(left: false),
                ],
              ),
              const SizedBox(height: 8),
              // Mouth
              _buildMouth(),
            ],
          ),
          // Gesture indicator
          Positioned(
            right: -4,
            top: -4,
            child: _buildGestureIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildEye({required bool left}) {
    final emotion = widget.state.emotion;
    if (emotion == 'angry' || emotion == 'scolding') {
      return Transform.rotate(
        angle: left ? -0.3 : 0.3,
        child: Container(
          width: 14,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }
    if (emotion == 'happy' || emotion == 'proud') {
      return Container(
        width: 12,
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    if (emotion == 'sad' || emotion == 'disappointed') {
      return Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 10,
            height: 2,
            color: Colors.blue.withValues(alpha: 0.3),
          ),
        ),
      );
    }
    if (emotion == 'surprised') {
      return Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
    }
    // neutral, annoyed, worried
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildMouth() {
    final emotion = widget.state.emotion;
    if (emotion == 'happy' || emotion == 'proud') {
      return CustomPaint(
        size: const Size(20, 10),
        painter: _SmilePainter(),
      );
    }
    if (emotion == 'sad' || emotion == 'disappointed') {
      return CustomPaint(
        size: const Size(20, 10),
        painter: _FrownPainter(),
      );
    }
    if (emotion == 'angry' || emotion == 'scolding') {
      return Container(
        width: 16,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    if (emotion == 'surprised') {
      return Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
    }
    // neutral
    return Container(
      width: 14,
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildGestureIndicator() {
    final gesture = widget.state.gesture;
    if (gesture == 'idle') return const SizedBox.shrink();

    IconData icon;
    switch (gesture) {
      case 'arms_crossed':
        icon = Icons.close;
        break;
      case 'pointing':
        icon = Icons.arrow_forward;
        break;
      case 'shaking_head':
        icon = Icons.swipe;
        break;
      case 'waving':
        icon = Icons.waving_hand;
        break;
      case 'thumbs_up':
        icon = Icons.thumb_up;
        break;
      case 'clapping':
        icon = Icons.celebration;
        break;
      case 'facepalm':
        icon = Icons.sentiment_dissatisfied;
        break;
      case 'beckoning':
        icon = Icons.back_hand;
        break;
      default:
        icon = Icons.emoji_emotions;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Icon(icon, size: 16, color: _emotionColor(widget.state.emotion)),
    );
  }

  Widget _buildSpeechBubble(String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
    );
  }

  Color _emotionColor(String emotion) {
    switch (emotion) {
      case 'happy':
        return Colors.amber;
      case 'angry':
        return Colors.red.shade400;
      case 'sad':
        return Colors.blue.shade300;
      case 'surprised':
        return Colors.orange;
      case 'annoyed':
        return Colors.deepOrange.shade300;
      case 'disappointed':
        return Colors.blueGrey;
      case 'scolding':
        return Colors.red.shade600;
      case 'proud':
        return Colors.green;
      case 'worried':
        return Colors.purple.shade200;
      default:
        return Colors.teal;
    }
  }
}

class _SmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 2)
      ..quadraticBezierTo(size.width / 2, size.height + 2, size.width, 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height - 2)
      ..quadraticBezierTo(size.width / 2, -2, size.width, size.height - 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
