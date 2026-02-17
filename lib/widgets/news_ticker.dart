import 'package:flutter/material.dart';

class NewsTicker extends StatefulWidget {
  final List<String> headlines;
  final TextStyle? style;
  final double velocity;

  const NewsTicker({
    super.key,
    required this.headlines,
    this.style,
    this.velocity = 40,
  });

  @override
  State<NewsTicker> createState() => _NewsTickerState();
}

class _NewsTickerState extends State<NewsTicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  TextPainter? _textPainter;
  double _textWidth = 0;

  String get _fullText => widget.headlines.join('   ·   ') + '   ·   ';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  @override
  void didUpdateWidget(NewsTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.headlines.length != widget.headlines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
    }
  }

  void _setup() {
    if (!mounted || widget.headlines.isEmpty) return;

    _textPainter?.dispose();
    final style = widget.style ?? const TextStyle(fontSize: 13);
    _textPainter = TextPainter(
      text: TextSpan(text: _fullText, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    _textWidth = _textPainter!.width;

    if (_textWidth <= 0) return;

    final durationMs = (_textWidth / widget.velocity * 1000).round();
    _controller.duration = Duration(milliseconds: durationMs);
    _controller.repeat();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _textPainter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_textPainter == null || _textWidth <= 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 20,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _TickerPainter(
              textPainter: _textPainter!,
              offset: _controller.value * _textWidth,
              textWidth: _textWidth,
            ),
          );
        },
      ),
    );
  }
}

class _TickerPainter extends CustomPainter {
  final TextPainter textPainter;
  final double offset;
  final double textWidth;

  _TickerPainter({
    required this.textPainter,
    required this.offset,
    required this.textWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final y = (size.height - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(-offset, y));
    textPainter.paint(canvas, Offset(-offset + textWidth, y));
  }

  @override
  bool shouldRepaint(_TickerPainter old) => offset != old.offset;
}
