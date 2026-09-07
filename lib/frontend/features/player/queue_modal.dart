import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../injection.dart';
import '../../shared/models/feed_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/cover_palette.dart';
import '../../shared/utils/haptic.dart';
import '../../shared/utils/responsive.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/empty_state.dart';
import 'now_playing/video_backdrop_texture.dart';

/// Shows the play queue with current track highlighted and upcoming tracks.
///
/// The sheet keeps the full player's own look: the blurred cover (or the live
/// visualizer video, when the player is in video mode) fills the background
/// and the upcoming songs are tappable to switch track instantly.
///
/// [showVideo]/[videoController] mirror the current cover↔video state of the
/// full player so the queue never looks like a flat grey panel.
void showQueueModal(
  BuildContext context, {
  bool showVideo = false,
  VideoController? videoController,
}) {
  final r = Responsive(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final basePanel = isDark ? const Color(0xFF141414) : const Color(0xFFF6F6F6);
  final fg = bestNeutral(basePanel);
  final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider<QueueCubit>.value(value: sl<QueueCubit>()),
        BlocProvider<PlayerCubit>.value(value: sl<PlayerCubit>()),
        BlocProvider<LikeCubit>.value(value: sl<LikeCubit>()),
      ],
      child: _QueueSheet(
        r: r,
        isDark: isDark,
        fg: fg,
        glowColor: glowColor,
        basePanel: basePanel,
        showVideo: showVideo,
        videoController: videoController,
      ),
    ),
  );
}

class _QueueSheet extends StatelessWidget {
  final Responsive r;
  final bool isDark;
  final Color fg;
  final Color glowColor;
  final Color basePanel;
  final bool showVideo;
  final VideoController? videoController;

  const _QueueSheet({
    required this.r,
    required this.isDark,
    required this.fg,
    required this.glowColor,
    required this.basePanel,
    this.showVideo = false,
    this.videoController,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QueueCubit, QueueState>(
      builder: (context, queue) {
        final trackCount = queue.tracks.length;
        final upcomingCount = queue.hasCurrent
            ? trackCount - queue.currentIndex - 1
            : trackCount;

        // Cover of the current (or first) queued song → the blurred backdrop.
        final cover = _resolveCover(queue);
        final h = MediaQuery.sizeOf(context).height;
        final sheetHeight = (h * 0.8).clamp(380.0, h * 0.88);

        return Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: basePanel,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // ── Backdrop: live video OR blurred cover ───────────────
              Positioned.fill(
                child: showVideo && videoController != null
                    ? VideoBackdropTexture(controller: videoController!)
                    : _coverBlur(cover, isDark),
              ),
              // Veil keeps every row readable over any artwork (same trick as
              // the lyrics sheet: opaque base + strong theme veil).
              Positioned.fill(
                child: Container(
                  color: (isDark ? Colors.black : Colors.white)
                      .withValues(alpha: isDark ? 0.74 : 0.55),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Handle bar ──────────────────────────────────────────
                  Container(
                    margin: EdgeInsets.only(top: r.spacingM),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: r.spacingM),

                  // ── Header ──────────────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                    child: Row(
                      children: [
                        Icon(Icons.queue_music, size: r.subtitleSize + 2, color: glowColor),
                        SizedBox(width: r.spacingS),
                        Text(
                          'Cola ($trackCount)',
                          style: TextStyle(
                            fontSize: r.subtitleSize + 1,
                            fontWeight: FontWeight.bold,
                            color: fg,
                          ),
                        ),
                        if (queue.shuffle || queue.repeatMode != RepeatMode.none) ...[
                          SizedBox(width: r.spacingS),
                          if (queue.shuffle)
                            _ModeChip(
                              icon: Icons.shuffle,
                              label: 'Shuffle',
                              r: r,
                              glowColor: glowColor,
                            ),
                          if (queue.repeatMode != RepeatMode.none) ...[
                            SizedBox(width: r.spacingXS),
                            _ModeChip(
                              icon: queue.repeatMode == RepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              label: queue.repeatMode == RepeatMode.one ? 'One' : 'All',
                              r: r,
                              glowColor: glowColor,
                            ),
                          ],
                        ],
                        const Spacer(),
                        if (upcomingCount > 0)
                          Text(
                            '$upcomingCount próximos',
                            style: TextStyle(
                              fontSize: r.footerSize,
                              color: fg.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.spacingM),
                  Divider(height: 1, color: fg.withValues(alpha: 0.12)),

                  // ── Track list ──────────────────────────────────────────
                  Flexible(
                    child: trackCount == 0
                        ? AnimatedEmptyState(
                            icon: Icons.queue_music,
                            title: 'Cola vacía',
                            subtitle: 'Reproduce una canción para empezar',
                            accentColor: glowColor,
                          )
                        : ReorderableListView.builder(
                            padding: EdgeInsets.only(
                              top: r.spacingXS,
                              bottom: r.bottomPadding,
                            ),
                            itemCount: trackCount,
                            onReorder: (oldIndex, newIndex) {
                              Haptic.medium();
                              context.read<QueueCubit>().reorder(oldIndex, newIndex);
                            },
                            proxyDecorator: (child, index, animation) => Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.transparent,
                              child: child,
                            ),
                            itemBuilder: (context, index) {
                              final track = queue.tracks[index];
                              final isCurrent =
                                  queue.hasCurrent && index == queue.currentIndex;
                              final isPlayed =
                                  queue.hasCurrent && index < queue.currentIndex;

                              return _QueueTrackTile(
                                key: ValueKey('queue_${track.id}'),
                                r: r,
                                fg: fg,
                                glowColor: glowColor,
                                track: track,
                                index: index,
                                isCurrent: isCurrent,
                                isPlayed: isPlayed,
                                onTap: isCurrent
                                    ? null
                                    : () {
                                        Haptic.tap();
                                        context.read<QueueCubit>().seekTo(index);
                                        Navigator.pop(context);
                                      },
                                onRemove: () {
                                  Haptic.tap();
                                  context.read<QueueCubit>().remove(index);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String? _resolveCover(QueueState queue) {
    try {
      if (queue.hasCurrent && queue.current != null) {
        return sl<LikeCubit>().resolveCoverFor(queue.current!);
      }
      if (queue.tracks.isNotEmpty) {
        return queue.tracks.first.coverUrl;
      }
    } catch (_) {}
    return null;
  }

  Widget _coverBlur(String? cover, bool isDark) {
    if (cover == null || cover.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Transform.scale(
          scale: 1.3,
          child: imageFromUrl(
            cover,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Responsive r;
  final Color glowColor;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.r,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: glowColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: r.footerSize - 2, color: glowColor),
          SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(fontSize: r.footerSize - 2, color: glowColor),
          ),
        ],
      ),
    );
  }
}

class _QueueTrackTile extends StatelessWidget {
  final Responsive r;
  final Color fg;
  final Color glowColor;
  final FeedItem track;
  final int index;
  final bool isCurrent;
  final bool isPlayed;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _QueueTrackTile({
    super.key,
    required this.r,
    required this.fg,
    required this.glowColor,
    required this.track,
    required this.index,
    required this.isCurrent,
    required this.isPlayed,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.spacingL,
            vertical: r.spacingS,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isCurrent ? glowColor : Colors.transparent,
                width: 3,
              ),
            ),
            color: isCurrent
                ? glowColor.withValues(alpha: 0.10)
                : (index.isOdd ? fg.withValues(alpha: 0.03) : null),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // ── Drag handle / Playing indicator ────────────────────
              // ReorderableListView maneja el long-press para arrastrar toda la fila.
              SizedBox(
                width: 24,
                child: isCurrent
                    ? Icon(Icons.play_arrow_rounded, color: glowColor, size: r.subtitleSize + 2)
                    : Row(
                        children: [
                          Icon(
                            Icons.drag_indicator,
                            size: r.subtitleSize,
                            color: fg.withValues(alpha: 0.2),
                          ),
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: r.footerSize,
                              color: isPlayed
                                  ? fg.withValues(alpha: 0.2)
                                  : fg.withValues(alpha: 0.45),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
              SizedBox(width: r.spacingS),

              // ── Cover thumbnail ─────────────────────────────────────
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageFromUrl(
                    track.coverUrl,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    fallback: Icon(
                      Icons.music_note,
                      size: 18,
                      color: fg.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              SizedBox(width: r.spacingM),

              // ── Info ────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.subtitleSize,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isPlayed
                            ? fg.withValues(alpha: 0.3)
                            : (isCurrent ? glowColor : fg),
                      ),
                    ),
                    if (track.artists != null && track.artists!.isNotEmpty)
                      Text(
                        track.artists!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: r.footerSize - 1,
                          color: isPlayed
                              ? fg.withValues(alpha: 0.18)
                              : fg.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Source badge ────────────────────────────────────────
              if (track.source != null &&
                  track.source!.isNotEmpty &&
                  !isCurrent)
                Container(
                  margin: EdgeInsets.only(right: r.spacingXS),
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _shortSource(track.source!),
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: fg.withValues(alpha: 0.4),
                    ),
                  ),
                ),

              // ── Remove button ───────────────────────────────────────
              if (onRemove != null && !isCurrent)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: r.subtitleSize,
                    color: fg.withValues(alpha: 0.35),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    Haptic.tap();
                    onRemove?.call();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortSource(String source) {
    if (source == 'spotify-web') return 'SP';
    if (source == 'ytmusic-spotiflac') return 'YT';
    if (source == 'tidal-web') return 'TD';
    if (source == 'qobuz-web') return 'QZ';
    if (source == 'deezer') return 'DZ';
    if (source == 'apple-music') return 'AM';
    if (source == 'amazon') return 'AZ';
    if (source == 'soundcloud') return 'SC';
    return source.length > 4
        ? source.substring(0, 4).toUpperCase()
        : source.toUpperCase();
  }
}
