import 'dart:ui';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../router/route_names.dart';
import '../utils/responsive.dart';
import '../utils/haptic.dart';
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
  final VoidCallback? onOpenPlayer;

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  void _openFull() {
    if (widget.onOpenPlayer != null) {
      widget.onOpenPlayer!();
    } else {
      context.push(RouteNames.nowPlaying.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.onSurface(isDark);

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
            final shuffleOn = queue.shuffle;
            final repeatMode = queue.repeatMode;
            final isBuffering = player.playbackState == PlayerPlaybackState.buffering;

            return TweenAnimationWidget(
              key: ValueKey('mp_tween_${track.id}'),
              trackId: track.id,
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v > 300) {
                    Haptic.tap();
                    context.read<PlayerCubit>().previous();
                  } else if (v < -300) {
                    Haptic.tap();
                    context.read<PlayerCubit>().next();
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.width * 0.04),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: fg.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          border: Border.all(
                            color: fg.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: r.spacingS,
                            vertical: r.spacingXS * 0.5,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top row: cover + track info + controls
                              Row(
                                children: [
                                  // Cover art
                                  GestureDetector(
                                    onTap: _openFull,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.shadow(isDark).withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: CoverImage(coverUrl: resolvedCover, localPath: null),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: r.spacingXS),
                                  // Track name + artist
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: r.footerSize,
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
                                              fontSize: r.footerSize - 2,
                                              color: fg.withValues(alpha: 0.5),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: r.spacingXS),
                                  // Shuffle
                                  GestureDetector(
                                    onTap: () => context.read<QueueCubit>().toggleShuffle(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        shuffleOn ? Icons.shuffle_rounded : Icons.shuffle,
                                        size: r.footerSize,
                                        color: shuffleOn ? fg : fg.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                  // Prev
                                  GestureDetector(
                                    onTap: () => context.read<PlayerCubit>().previous(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.skip_previous_rounded,
                                        size: r.footerSize + 2,
                                        color: fg.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  // Play/Pause
                                  GestureDetector(
                                    onTap: () {
                                      Haptic.medium();
                                      context.read<PlayerCubit>().togglePlayPause();
                                    },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: fg.withValues(alpha: 0.12),
                                      ),
                                      child: Center(
                                        child: isBuffering
                                            ? SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: fg.withValues(alpha: 0.7),
                                                ),
                                              )
                                            : Icon(
                                                player.isPlaying
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                                color: fg,
                                                size: 18,
                                              ),
                                      ),
                                    ),
                                  ),
                                  // Next
                                  GestureDetector(
                                    onTap: () => context.read<PlayerCubit>().next(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.skip_next_rounded,
                                        size: r.footerSize + 2,
                                        color: fg.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  // Repeat
                                  GestureDetector(
                                    onTap: () => context.read<QueueCubit>().cycleRepeatMode(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        repeatMode == RepeatMode.one
                                            ? Icons.repeat_one_rounded
                                            : Icons.repeat_rounded,
                                        size: r.footerSize,
                                        color: repeatMode == RepeatMode.none
                                            ? fg.withValues(alpha: 0.3)
                                            : fg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Bottom row: progress slider + times
                              Padding(
                                padding: const EdgeInsets.only(top: 0),
                                child: Row(
                                  children: [
                                    Text(
                                      _fmtDuration(player.position),
                                      style: TextStyle(
                                        fontSize: r.footerSize - 3,
                                        color: fg.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    Expanded(
                                      child: _AnimatedProgressBar(
                                        progress: progress,
                                        isPlaying: player.isPlaying,
                                        color: fg,
                                        onChangeEnd: (v) =>
                                            context.read<PlayerCubit>().seekToProgress(v),
                                      ),
                                    ),
                                    Text(
                                      _fmtDuration(dur),
                                      style: TextStyle(
                                        fontSize: r.footerSize - 3,
                                        color: fg.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

/// Custom animated progress bar with pulsing glow effect.
class _AnimatedProgressBar extends StatefulWidget {
  final double progress;
  final bool isPlaying;
  final Color color;
  final ValueChanged<double>? onChangeEnd;

  const _AnimatedProgressBar({
    required this.progress,
    required this.isPlaying,
    required this.color,
    this.onChangeEnd,
  });

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  bool _dragging = false;
  double _dragProgress = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.isPlaying) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isPlaying && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0.6;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayProgress = _dragging ? _dragProgress : widget.progress;
    final fg = widget.color;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const trackH = 3.0;
        const thumbR = 5.0;

        return GestureDetector(
          onHorizontalDragStart: (details) {
            _dragging = true;
            final x = details.localPosition.dx.clamp(0.0, width);
            setState(() => _dragProgress = x / width);
          },
          onHorizontalDragUpdate: (details) {
            final x = details.localPosition.dx.clamp(0.0, width);
            setState(() => _dragProgress = x / width);
          },
          onHorizontalDragEnd: (details) {
            _dragging = false;
            widget.onChangeEnd?.call(_dragProgress);
          },
          onTapDown: (details) {
            _dragging = true;
            final x = details.localPosition.dx.clamp(0.0, width);
            setState(() => _dragProgress = x / width);
          },
          onTapUp: (details) {
            _dragging = false;
            widget.onChangeEnd?.call(_dragProgress);
          },
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) {
              final thumbX = displayProgress * width;
              final glowRadius = widget.isPlaying ? 6.0 + (_pulseAnim.value * 6.0) : 0.0;
              final thumbScale = widget.isPlaying ? 0.8 + (_pulseAnim.value * 0.4) : 1.0;

              return CustomPaint(
                size: Size(width, thumbR * 2 + 4),
                painter: _ProgressBarPainter(
                  progress: displayProgress,
                  thumbX: thumbX,
                  thumbRadius: thumbR * thumbScale,
                  glowRadius: glowRadius,
                  trackHeight: trackH,
                  activeColor: fg.withValues(alpha: 0.7),
                  inactiveColor: fg.withValues(alpha: 0.1),
                  thumbColor: fg.withValues(alpha: 0.9),
                  glowColor: fg,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  final double progress;
  final double thumbX;
  final double thumbRadius;
  final double glowRadius;
  final double trackHeight;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final Color glowColor;

  _ProgressBarPainter({
    required this.progress,
    required this.thumbX,
    required this.thumbRadius,
    required this.glowRadius,
    required this.trackHeight,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final trackTop = centerY - trackHeight / 2;
    final trackRect = RRect.fromLTRBXY(0, trackTop, size.width, trackTop + trackHeight, 2, 2);

    // Inactive track
    final inactivePaint = Paint()..color = inactiveColor;
    canvas.drawRRect(trackRect, inactivePaint);

    // Active track with gradient
    if (progress > 0) {
      final activePaint = Paint()
        ..shader = LinearGradient(
          colors: [activeColor, activeColor.withValues(alpha: 0.4)],
        ).createShader(Rect.fromLTWH(0, 0, thumbX, size.height));
      canvas.drawRRect(
        RRect.fromLTRBXY(0, trackTop, thumbX, trackTop + trackHeight, 2, 2),
        activePaint,
      );
    }

    // Glow behind thumb
    if (glowRadius > 0) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
      canvas.drawCircle(Offset(thumbX, centerY), thumbRadius + glowRadius * 0.5, glowPaint);
    }

    // Thumb
    final thumbPaint = Paint()..color = thumbColor;
    canvas.drawCircle(Offset(thumbX, centerY), thumbRadius, thumbPaint);

    // Inner dot on thumb
    final innerPaint = Paint()..color = inactiveColor.withValues(alpha: 0.4);
    canvas.drawCircle(Offset(thumbX, centerY), thumbRadius * 0.35, innerPaint);
  }

  @override
  bool shouldRepaint(_ProgressBarPainter old) => true;
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
