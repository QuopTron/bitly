import 'package:flutter/material.dart' hide RepeatMode;
import '../../shared/utils/haptic.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../shared/utils/responsive.dart';
import '../../shared/models/feed_models.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/empty_state.dart';

/// Shows the play queue with current track highlighted and upcoming tracks.
void showQueueModal(BuildContext context) {
  final r = Responsive(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final onBg = isDark ? Colors.white : Colors.black;
  final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _QueueSheet(r: r, isDark: isDark, onBg: onBg, glowColor: glowColor),
  );
}

class _QueueSheet extends StatelessWidget {
  final Responsive r;
  final bool isDark;
  final Color onBg;
  final Color glowColor;

  const _QueueSheet({
    required this.r,
    required this.isDark,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return BlocBuilder<QueueCubit, QueueState>(
      builder: (context, queue) {
        final trackCount = queue.tracks.length;
        final upcomingCount = queue.hasCurrent
            ? trackCount - queue.currentIndex - 1
            : trackCount;

        return Container(
          margin: EdgeInsets.only(top: r.spacingXL * 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(maxHeight: r.height * 0.7),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle bar ────────────────────────────────────────────
                Container(
                  margin: EdgeInsets.only(top: r.spacingM),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: onBg.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: r.spacingM),

                // ── Header ────────────────────────────────────────────────
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
                          color: onBg,
                        ),
                      ),
                      if (queue.shuffle || queue.repeatMode != RepeatMode.none) ...[
                        SizedBox(width: r.spacingS),
                        if (queue.shuffle)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: glowColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shuffle, size: r.footerSize - 2, color: glowColor),
                                SizedBox(width: 2),
                                Text(
                                  'Shuffle',
                                  style: TextStyle(fontSize: r.footerSize - 2, color: glowColor),
                                ),
                              ],
                            ),
                          ),
                        if (queue.repeatMode != RepeatMode.none) ...[
                          SizedBox(width: r.spacingXS),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: glowColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  queue.repeatMode == RepeatMode.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  size: r.footerSize - 2,
                                  color: glowColor,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  queue.repeatMode == RepeatMode.one ? 'One' : 'All',
                                  style: TextStyle(fontSize: r.footerSize - 2, color: glowColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      const Spacer(),
                      if (upcomingCount > 0)
                        Text(
                          '$upcomingCount próximos',
                          style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.4)),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: r.spacingM),
                Divider(height: 1, color: onBg.withValues(alpha: 0.08)),

                // ── Track list ────────────────────────────────────────────
                Flexible(
                  child: trackCount == 0
                      ? AnimatedEmptyState(
                          icon: Icons.queue_music,
                          title: 'Cola vacía',
                          subtitle: 'Reproduce una canción para empezar',
                          accentColor: glowColor,
                        )
                      : ReorderableListView.builder(
                          padding: EdgeInsets.only(top: r.spacingXS, bottom: r.bottomPadding),
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
                            final isCurrent = queue.hasCurrent && index == queue.currentIndex;
                            final isPlayed = queue.hasCurrent && index < queue.currentIndex;

                            return _QueueTrackTile(
                              key: ValueKey('queue_${track.id}'),
                              r: r,
                              onBg: onBg,
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
          ),
        );
      },
    );
  }
}

class _QueueTrackTile extends StatelessWidget {
  final Responsive r;
  final Color onBg;
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
    required this.onBg,
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
          padding: EdgeInsets.symmetric(horizontal: r.spacingL, vertical: r.spacingS),
          decoration: BoxDecoration(
            border: isCurrent
                ? Border(left: BorderSide(color: glowColor, width: 3))
                : Border(left: BorderSide(color: Colors.transparent, width: 3)),
            color: isCurrent
                ? glowColor.withValues(alpha: 0.08)
                : index.isOdd
                    ? onBg.withValues(alpha: 0.02)
                    : null,
          ),
          child: Row(
            children: [
              // ── Drag handle / Playing indicator ────────────────────
              // Usamos ReorderableListView que automaticamente maneja el long-press
              // para activar el arrastre en toda la fila.
              SizedBox(
                width: 24,
                child: isCurrent
                    ? Icon(Icons.play_arrow_rounded, color: glowColor, size: r.subtitleSize + 2)
                    : Row(
                        children: [
                          Icon(
                            Icons.drag_indicator,
                            size: r.subtitleSize,
                            color: onBg.withValues(alpha: 0.2),
                          ),
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: r.footerSize,
                              color: isPlayed
                                  ? onBg.withValues(alpha: 0.2)
                                  : onBg.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
              SizedBox(width: r.spacingS),

              // ── Cover thumbnail ─────────────────────────────────────
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: imageFromUrl(
                    track.coverUrl,
                    width: 36, height: 36, fit: BoxFit.cover,
                    fallback: Icon(Icons.music_note, size: 18, color: onBg.withValues(alpha: 0.3)),
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
                            ? onBg.withValues(alpha: 0.3)
                            : (isCurrent ? glowColor : onBg),
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
                              ? onBg.withValues(alpha: 0.15)
                              : onBg.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Source badge ────────────────────────────────────────
              if (track.source != null && track.source!.isNotEmpty && !isCurrent)
                Container(
                  margin: EdgeInsets.only(right: r.spacingXS),
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: onBg.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _shortSource(track.source!),
                    style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.3)),
                  ),
                ),

              // ── Remove button ───────────────────────────────────────
              if (onRemove != null && !isCurrent)
                IconButton(
                  icon: Icon(Icons.close, size: r.subtitleSize, color: onBg.withValues(alpha: 0.3)),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () { Haptic.tap(); onRemove?.call(); },
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
    return source.length > 4 ? source.substring(0, 4).toUpperCase() : source.toUpperCase();
  }
}


