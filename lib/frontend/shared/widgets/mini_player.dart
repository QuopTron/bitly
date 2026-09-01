import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../router/route_names.dart';
import '../utils/responsive.dart';
import '../theme/app_colors.dart';
import 'cover_image.dart';

String _fmtDuration(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key, this.onOpenPlayer});

  /// Optional navigation callback (used by the global overlay so it can push
  /// the full player without depending on a go_router context underneath).
  final VoidCallback? onOpenPlayer;

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  bool _expanded = false;

  void _openFull() {
    if (widget.onOpenPlayer != null) {
      widget.onOpenPlayer!();
    } else {
      context.push(RouteNames.nowPlaying.path);
    }
  }

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

    return BlocBuilder<QueueCubit, QueueState>(
      builder: (context, queue) {
        if (!queue.hasCurrent) return const SizedBox.shrink();
        final track = queue.current!;
        return BlocBuilder<PlayerCubit, AudioPlayerState>(
          builder: (context, player) {
            final resolvedCover = context.read<LikeCubit>().resolveCoverFor(track);
            final dur = player.duration;
            final totalMs = dur.inMilliseconds;
            final progress =
                totalMs > 0 ? (player.position.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;

            final controlSize = r.subtitleSize + 2;
            final shuffleOn = queue.shuffle;
            final repeatMode = queue.repeatMode;

            final bgColor = (isDark ? const Color(0xFF141414) : Colors.white)
                .withValues(alpha: 0.92);

            return TweenAnimationWidget(
              key: ValueKey('mp_tween_${track.id}'),
              trackId: track.id,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                    color: bgColor,
                    boxShadow: [
                      BoxShadow(
                        color: player.isPlaying
                            ? glowColor.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: player.isPlaying ? 12 : 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: fg.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(glowColor),
                      ),
                    ),
                    InkWell(
                      onTap: _toggleExpanded,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: player.isPlaying
                                      ? glowColor.withValues(alpha: 0.4)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                                boxShadow: player.isPlaying
                                    ? [
                                        BoxShadow(
                                          color: glowColor.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: CoverImage(coverUrl: resolvedCover, localPath: null),
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
                                      color: fg,
                                    ),
                                  ),
                                  if (track.artists != null && track.artists!.isNotEmpty)
                                    Text(
                                      track.artists!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: r.footerSize,
                                        color: fg.withValues(alpha: 0.5),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _IconBtn(
                              icon: shuffleOn ? Icons.shuffle_rounded : Icons.shuffle,
                              color: shuffleOn ? glowColor : fg.withValues(alpha: 0.35),
                              size: controlSize,
                              onTap: () => context.read<QueueCubit>().toggleShuffle(),
                            ),
                            _IconBtn(
                              icon: Icons.skip_previous_rounded,
                              color: fg.withValues(alpha: 0.4),
                              size: controlSize,
                              onTap: () => context.read<PlayerCubit>().previous(),
                            ),
                            _IconBtn(
                              icon: player.playbackState == PlayerPlaybackState.buffering
                                  ? Icons.hourglass_empty_rounded
                                  : (player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              color: glowColor,
                              size: controlSize + 6,
                              emphasized: true,
                              onTap: () => context.read<PlayerCubit>().togglePlayPause(),
                            ),
                            _IconBtn(
                              icon: Icons.skip_next_rounded,
                              color: fg.withValues(alpha: 0.4),
                              size: controlSize,
                              onTap: () => context.read<PlayerCubit>().next(),
                            ),
                            _IconBtn(
                              icon: repeatMode == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                              color: repeatMode == RepeatMode.none ? fg.withValues(alpha: 0.35) : glowColor,
                              size: controlSize,
                              onTap: () => context.read<QueueCubit>().cycleRepeatMode(),
                            ),
                            _IconBtn(
                              icon: Icons.keyboard_arrow_up_rounded,
                              color: fg.withValues(alpha: 0.5),
                              size: controlSize - 2,
                              onTap: _openFull,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_expanded)
                      Padding(
                        padding: EdgeInsets.fromLTRB(r.spacingM, 0, r.spacingM, r.spacingXS),
                        child: Row(
                          children: [
                            Text(_fmtDuration(player.position),
                                style: TextStyle(fontSize: r.footerSize * 0.85, color: fg.withValues(alpha: 0.5))),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  activeTrackColor: glowColor,
                                  inactiveTrackColor: fg.withValues(alpha: 0.08),
                                  thumbColor: glowColor,
                                  overlayColor: glowColor.withValues(alpha: 0.12),
                                ),
                                child: Slider(
                                  value: progress,
                                  onChangeEnd: (v) => context.read<PlayerCubit>().seekToProgress(v),
                                  onChanged: (_) {},
                                ),
                              ),
                            ),
                            Text(_fmtDuration(dur),
                                style: TextStyle(fontSize: r.footerSize * 0.85, color: fg.withValues(alpha: 0.5))),
                          ],
                        ),
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

/// Animates a fade + slide-up when the track ID changes (new song).
class TweenAnimationWidget extends StatefulWidget {
  final String trackId;
  final Widget child;

  const TweenAnimationWidget({super.key, required this.trackId, required this.child});

  @override
  State<TweenAnimationWidget> createState() => _TweenAnimationWidgetState();
}

class _TweenAnimationWidgetState extends State<TweenAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(TweenAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) {
      _ctrl..reset()..forward();
    }
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
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Transform.translate(offset: _slideAnim.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final base = InkResponse(
      onTap: onTap,
      radius: size * 1.4,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, color: color, size: size),
      ),
    );
    if (!emphasized) return base;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.18),
        ),
        child: InkResponse(onTap: onTap, child: Icon(icon, color: color, size: size)),
      ),
    );
  }
}