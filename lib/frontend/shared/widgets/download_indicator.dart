import 'package:flutter/material.dart';
import '../../../backend/cache/download_state.dart';
export '../../../backend/cache/download_state.dart';

class DownloadIndicator extends StatelessWidget {
  final DownloadState state;
  final double size;
  final double? progress; // 0.0..1.0, only used when state == inProgress

  /// Default dot size used across the app for download status indicators.
  static const double defaultSize = 8;

  const DownloadIndicator({super.key, this.state = DownloadState.none, this.size = defaultSize, this.progress});

  @override
  Widget build(BuildContext context) {
    // When in progress, use an animated pulsing dot.
    if (state == DownloadState.inProgress) {
      if (progress != null && progress! > 0) {
        return _ProgressDot(size: size, color: _color, progress: progress!);
      }
      return _PulsingDot(size: size, color: _color);
    }

    final hasGlow = state == DownloadState.completed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: _color.withValues(alpha: 0.5),
                  blurRadius: size * 1.5,
                  spreadRadius: size * 0.3,
                ),
              ]
            : null,
      ),
    );
  }

  Color get _color {
    switch (state) {
      case DownloadState.completed:
        return const Color(0xFF4CAF50); // verde
      case DownloadState.inProgress:
        return const Color(0xFFFF9800); // naranja
      case DownloadState.interrupted:
        return const Color(0xFFE53935); // rojo (error)
      case DownloadState.queued:
        return const Color(0xFF9E9E9E); // gris medio
      case DownloadState.none:
        return const Color(0xFF808080); // gris
    }
  }
}

/// A dot that gently pulses while the download is in progress.
class _PulsingDot extends StatefulWidget {
  final double size;
  final Color color;

  const _PulsingDot({required this.size, required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final glowAlpha = 0.15 + t * 0.25; // 0.15 → 0.4
        final scale = 0.85 + t * 0.15; // 0.85 → 1.0
        return Container(
          width: widget.size * scale,
          height: widget.size * scale,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glowAlpha),
                blurRadius: widget.size * 2,
                spreadRadius: widget.size * 0.5,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small circular progress indicator for downloads with known progress.
class _ProgressDot extends StatelessWidget {
  final double size;
  final Color color;
  final double progress;

  const _ProgressDot({required this.size, required this.color, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }
}
