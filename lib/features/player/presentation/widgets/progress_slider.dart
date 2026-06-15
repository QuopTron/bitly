import 'package:flutter/material.dart';

class ProgressSlider extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const ProgressSlider({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final pos = position.inMilliseconds.toDouble().clamp(0, total).toDouble();
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF1DB954),
            inactiveTrackColor: const Color(0xFF282828),
            thumbColor: const Color(0xFF1DB954),
            overlayColor: const Color(0xFF1DB954).withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: pos,
            max: total,
            onChanged: (v) => onSeek(Duration(milliseconds: v.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              Text(_fmt(duration), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}
