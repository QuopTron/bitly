import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/utils/haptic.dart';
import '../../../shared/models/feed_models.dart';
import '../../../../backend/services/like_cubit.dart';
import '../../../../backend/services/player_cubit.dart';
import '../../../../backend/services/queue_cubit.dart';
import '../../../../injection.dart';

class PlayerControls extends StatelessWidget {
  final Responsive r;
  final bool isDark;
  final QueueState queue;
  final FeedItem track;
  final bool lyricsLoading;
  final bool hasVideo;
  final bool showVideo;
  final VoidCallback? onToggleLyrics;
  final VoidCallback? onToggleVideo;

  const PlayerControls({
    super.key,
    required this.r,
    required this.isDark,
    required this.queue,
    required this.track,
    this.lyricsLoading = false,
    this.hasVideo = false,
    this.showVideo = false,
    this.onToggleLyrics,
    this.onToggleVideo,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerCubit>().state;
    final muted = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45);
    final active = isDark ? Colors.white : Colors.black;
    final iconM = r.subtitleSize + 4;
    final iconL = r.subtitleSize + 9;
    final gap = r.spacingL;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BlocBuilder<LikeCubit, LikeState>(
          builder: (context, _) {
            final liked = context.read<LikeCubit>().isLiked(track);
            return GestureDetector(
              onTap: () { Haptic.medium(); context.read<LikeCubit>().toggleLike(track); },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey(liked),
                  color: liked ? Colors.redAccent : muted,
                  size: iconM,
                ),
              ),
            );
          },
        ),
        SizedBox(width: gap),
        GestureDetector(
          onTap: () { Haptic.tap(); sl<QueueCubit>().toggleShuffle(); },
          child: Icon(
            queue.shuffle ? Icons.shuffle_rounded : Icons.shuffle,
            color: queue.shuffle ? active : muted,
            size: iconM,
          ),
        ),
        SizedBox(width: gap),
        GestureDetector(
          onTap: () { Haptic.tap(); sl<QueueCubit>().previous(); },
          child: Icon(Icons.skip_previous_rounded, color: active, size: iconL),
        ),
        SizedBox(width: gap),
        GestureDetector(
          onTap: () { Haptic.medium(); sl<PlayerCubit>().togglePlayPause(); },
          child: Container(
            width: r.subtitleSize + 34,
            height: r.subtitleSize + 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active.withValues(alpha: 0.12),
              border: Border.all(
                color: active.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: player.playbackState == PlayerPlaybackState.buffering
                ? Center(
                    child: SizedBox(
                      width: r.subtitleSize + 2,
                      height: r.subtitleSize + 2,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(active.withValues(alpha: 0.7)),
                      ),
                    ),
                  )
                : Icon(
                    player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: active,
                    size: r.subtitleSize + 14,
                  ),
          ),
        ),
        SizedBox(width: gap),
        GestureDetector(
          onTap: () { Haptic.tap(); sl<QueueCubit>().next(); },
          child: Icon(Icons.skip_next_rounded, color: active, size: iconL),
        ),
        SizedBox(width: gap),
        GestureDetector(
          onTap: () { Haptic.tap(); sl<QueueCubit>().cycleRepeatMode(); },
          child: Icon(
            _repeatIcon(queue.repeatMode),
            color: queue.repeatMode != RepeatMode.none ? active : muted,
            size: iconM,
          ),
        ),
        SizedBox(width: r.spacingS),
        GestureDetector(
          onTap: lyricsLoading ? null : onToggleLyrics,
          child: lyricsLoading
              ? SizedBox(
                  width: r.subtitleSize + 2,
                  height: r.subtitleSize + 2,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: active.withValues(alpha: 0.6)),
                )
              : Icon(Icons.lyrics_outlined, color: muted, size: r.subtitleSize + 2),
        ),
        if (hasVideo) ...[
          SizedBox(width: r.spacingS),
          GestureDetector(
            onTap: onToggleVideo,
            child: Icon(
              showVideo ? Icons.image_outlined : Icons.videocam_outlined,
              color: showVideo ? active : muted,
              size: r.subtitleSize + 2,
            ),
          ),
        ],
      ],
    );
  }

  IconData _repeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.none: return Icons.repeat_rounded;
      case RepeatMode.one: return Icons.repeat_one_rounded;
      case RepeatMode.all: return Icons.repeat_rounded;
    }
  }
}
