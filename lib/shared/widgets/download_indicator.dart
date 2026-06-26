import 'dart:math' as math;
import 'package:flutter/material.dart';

enum DownloadState { none, inProgress, completed }

class DownloadIndicator extends StatelessWidget {
  final DownloadState state;
  final double progress;
  final double size;

  const DownloadIndicator({super.key, this.state = DownloadState.none, this.progress = 0.0, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (state == DownloadState.inProgress)
            CustomPaint(
              size: Size(size, size),
              painter: _DownloadRingPainter(progress: progress.clamp(0.0, 1.0), color: const Color(0xFFFF9800)),
            ),
          if (state == DownloadState.completed)
            CustomPaint(
              size: Size(size, size),
              painter: _DownloadRingPainter(progress: 1.0, color: const Color(0xFF4CAF50)),
            ),
          Container(
            width: size * 0.36, height: size * 0.36,
            decoration: const BoxDecoration(color: Color(0xFFB0B0B0), shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

class _DownloadRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _DownloadRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    paint.color = Colors.white.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, paint);

    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DownloadRingPainter old) => old.progress != progress;
}
