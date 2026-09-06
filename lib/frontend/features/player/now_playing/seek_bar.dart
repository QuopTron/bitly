import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/utils/responsive.dart';
import '../../../../backend/services/player_cubit.dart';

class SeekBar extends StatelessWidget {
  final Responsive r;
  final bool isDark;
  final AudioPlayerState player;

  const SeekBar({
    super.key,
    required this.r,
    required this.isDark,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final duration = player.duration;
    final position = player.position;
    final remaining = duration - position;
    final fg = isDark ? Colors.white : Colors.black;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: fg.withValues(alpha: 0.7),
            inactiveTrackColor: fg.withValues(alpha: 0.15),
            thumbColor: fg.withValues(alpha: 0.8),
            overlayColor: fg.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: player.progress.clamp(0.0, 1.0),
            onChanged: (v) => context.read<PlayerCubit>().seekToProgress(v),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingS),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(
                  fontSize: r.footerSize,
                  color: fg.withValues(alpha: 0.5),
                ),
              ),
              Text(
                '-${_formatDuration(remaining)}',
                style: TextStyle(
                  fontSize: r.footerSize,
                  color: fg.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
