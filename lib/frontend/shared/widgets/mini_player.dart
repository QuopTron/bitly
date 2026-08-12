import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../utils/responsive.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../theme/app_colors.dart';
import 'cover_image.dart';
import 'glass_container.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

    return BlocBuilder<QueueCubit, QueueState>(
      builder: (context, queue) {
        if (!queue.hasCurrent) return const SizedBox.shrink();
        final track = queue.current!;
        return BlocBuilder<PlayerCubit, AudioPlayerState>(
          builder: (context, player) {
            final resolvedCover = context.read<LikeCubit>().resolveCoverFor(track);
            return GestureDetector(
              onTap: () {
                context.push('/now_playing');
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingXL, vertical: r.spacingXS),
                child: GlassContainer(
                  borderRadius: 16,
                  borderColor: glowColor.withValues(alpha: 0.15),
                  bgColor: (isDark ? const Color(0xFF1A1A1A) : Colors.white).withValues(alpha: 0.85),
                  padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CoverImage(
                            coverUrl: resolvedCover,
                            localPath: null,
                          ),
                        ),
                      ),
                      SizedBox(width: r.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: r.subtitleSize,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            if (track.artists != null && track.artists!.isNotEmpty)
                              Text(
                                track.artists!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: r.footerSize,
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: r.spacingS),
                      IconButton(
                        icon: Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: glowColor,
                        ),
                        iconSize: r.subtitleSize + 4,
                        onPressed: () => context.read<PlayerCubit>().togglePlayPause(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}


