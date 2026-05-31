import 'dart:math';
import 'package:flutter/material.dart';

class AudioVisualizer extends StatefulWidget {
  final Color? color;

  const AudioVisualizer({super.key, this.color});

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _bars = List.generate(48, (_) => 0.3);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        for (var i = 0; i < _bars.length; i++) {
          final t = _controller.value;
          final noise = sin(t * 2 * pi * 3 + i * 0.8) * 0.3;
          final target = (noise + 1) * 0.5;
          _bars[i] = _bars[i] + (target - _bars[i]) * 0.15;
        }
        return CustomPaint(
          painter: _VisualizerPainter(_bars, color),
          size: Size.infinite,
        );
      },
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final List<double> bars;
  final Color color;

  _VisualizerPainter(this.bars, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final count = bars.length;
    final gap = 4.0;
    final w = (size.width - gap * (count - 1)) / count;
    if (w <= 0) return;
    final cx = size.width / 2;
    final barW = w / 2;

    for (var i = 0; i < count; i++) {
      final h = bars[i] * size.height * 0.7;
      final x = cx - (count / 2 - i) * (w + gap) - w / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, size.height / 2),
            width: barW,
            height: h.clamp(2, size.height * 0.7),
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VisualizerPainter old) => true;
}
