import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/utils/responsive.dart';
import '../../shared/utils/haptic.dart';
import '../../shared/models/feed_models.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../shared/theme/app_colors.dart';
import '../../../injection.dart';
import '../../shared/widgets/cover_image.dart';
import 'queue_modal.dart';
import 'lyrics_sheet.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage>
    with SingleTickerProviderStateMixin {
  bool _showVideo = false;
  final Player _videoPlayer = Player();
  VideoController? _videoController;
  StreamSubscription? _queueSub;
  bool _hasVideo = false;

  /// True while a lyrics fetch triggered from the controls is in flight — the
  /// lyrics button shows a tiny spinner instead of silently doing nothing.
  bool _lyricsLoading = false;

  // ── Canvas video state ────────────────────────────────────────
  /// Id of the track whose video is preloaded and ready to alternate with the
  /// cover (drives the videocam button on the artwork + controls row).
  String? _videoTrackId;
  ValueNotifier<String?>? _videoReadySrc;

  // ── Swipe-down-to-dismiss ─────────────────────────────────────
  final ValueNotifier<double> _dragOffset = ValueNotifier(0);
  late final AnimationController _dragAnim;
  double _dragFrom = 0;
  double _dragTo = 0;

  @override
  void initState() {
    super.initState();
    _videoController = VideoController(_videoPlayer);
    _dragAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(_onDragAnimTick);
    // Reset video/lyrics when track changes
    _queueSub = sl<QueueCubit>().stream.listen((queueState) {
      _hasVideo = false;
      if (_showVideo) {
        _videoPlayer.stop();
        setState(() => _showVideo = false);
      }
      // A lyrics modal, if open, follows the new current track on its own;
      // here we only reset our loading flag for the controls-row spinner.
      _lyricsLoading = false;
      _videoTrackId = null;
    });
    // When the background video finishes preloading, we only flip the
    // videocam button visible on the cover — the user alternates manually.
    _videoReadySrc = sl<PlayerCubit>().preloadedVideoReady
      ..addListener(_onVideoReadyChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onVideoReadyChanged());
  }

  @override
  void dispose() {
    _videoReadySrc?.removeListener(_onVideoReadyChanged);
    _queueSub?.cancel();
    _videoPlayer.dispose();
    _dragAnim.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  // ── Swipe-down dismiss helpers ────────────────────────────────

  void _onDragAnimTick() {
    final t = Curves.easeOutCubic.transform(_dragAnim.value);
    _dragOffset.value = _dragFrom + (_dragTo - _dragFrom) * t;
  }

  double _dragOpacity(double dy, double height) {
    final o = 1.0 - dy / (height * 0.62);
    if (o < 0) return 0;
    if (o > 1) return 1;
    return o;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dragAnim.isAnimating) return;
    final height = MediaQuery.sizeOf(context).height;
    final next = _dragOffset.value + d.delta.dy;
    _dragOffset.value = next < 0 ? 0 : (next > height * 0.92 ? height * 0.92 : next);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dragAnim.isAnimating) return;
    final height = MediaQuery.sizeOf(context).height;
    final velocity = d.primaryVelocity ?? 0;
    final shouldClose = _dragOffset.value > height * 0.08 || velocity > 700;
    _dragFrom = _dragOffset.value;
    _dragTo = shouldClose ? height * 0.95 : 0.0;
    _dragAnim.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      if (shouldClose) {
        Navigator.of(context).pop();
      } else {
        _dragOffset.value = 0;
      }
    });
  }

  // ── Canvas video helpers ──────────────────────────────────────

  /// Called when the current track's video finishes preloading (or on first
  /// frame, if it was already ready). Only reflects readiness in the UI — the
  /// cover stays the default and the videocam button appears to alternate.
  void _onVideoReadyChanged() {
    if (!mounted) return;
    final cubit = sl<PlayerCubit>();
    final queue = sl<QueueCubit>().state;
    if (!queue.hasCurrent) return;
    final track = queue.current!;
    if (_videoTrackId != track.id) {
      _videoTrackId = track.id;
      _hasVideo = false;
      _showVideo = false;
    }
    final url = cubit.preloadedVideoReady.value;
    final ready = url != null && url.isNotEmpty;
    if (ready != _hasVideo) {
      setState(() => _hasVideo = ready);
    }
  }

  // ── Lyrics / karaoke helpers ──────────────────────────────────

  /// Opens the karaoke modal. Uses the preloaded LRC when available;
  /// otherwise fetches on demand (spinner state lives in [context] itself).
  /// Returns true when a modal was opened (or is being fetched to open).
  void _toggleLyrics(BuildContext ctx) {
    final cubit = sl<PlayerCubit>();
    final queue = sl<QueueCubit>().state;
    if (!queue.hasCurrent) return;
    final track = queue.current!;

    void openSheet(String text) {
      if (!ctx.mounted) return;
      showLyricsSheet(ctx, track: track, lyrics: text);
    }

    final preloaded = cubit.preloadedLyrics;
    if (preloaded != null && preloaded.isNotEmpty) {
      openSheet(preloaded);
      return;
    }
    // Nothing preloaded — rescue the LRC on demand.
    setState(() => _lyricsLoading = true);
    cubit.fetchLyricsOnDemand(track).then((text) {
      if (!mounted) return;
      setState(() => _lyricsLoading = false);
      if (text != null && text.isNotEmpty) {
        openSheet(text);
      } else if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Sin letras para esta canción'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  /// Secondary line under the artist: "Album  •  Source".
  String? _metaSubtitle(FeedItem track) {
    final parts = <String>[];
    if (track.albumName != null && track.albumName!.isNotEmpty) parts.add(track.albumName!);
    final src = _sourceLabel(track.source);
    if (src != null) parts.add(src);
    if (parts.isEmpty) return null;
    return parts.join('  •  ');
  }

  String? _sourceLabel(String? source) {
    if (source == null || source.isEmpty) return null;
    switch (source) {
      case 'deezer': return 'Deezer';
      case 'spotify-web': return 'Spotify';
      case 'spotify': return 'Spotify';
      case 'apple-music': return 'Apple Music';
      case 'ytmusic-spotiflac': return 'YTMusic';
      case 'qobuz-web': return 'Qobuz';
      case 'tidal-web': return 'Tidal';
      case 'soundcloud': return 'SoundCloud';
      case 'amazon': return 'Amazon Music';
      case 'pandora': return 'Pandora';
      case 'musicbrainz': return 'MusicBrainz';
      case 'youtube': return 'YouTube';
      default:
        return source
            .split(RegExp(r'[-_ ]'))
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
    }
  }

  String? _resolveLocalVideoUrl(FeedItem track, String? downloadPath) {
    if (downloadPath == null) return null;
    final videoExts = ['mp4', 'webm', 'mkv', 'avi'];

    // 1. Try by track id (legacy naming)
    for (final ext in videoExts) {
      final path = '$downloadPath\\${track.id}.$ext';
      if (File(path).existsSync()) {
        return 'file://${path.replaceAll('\\', '/')}';
      }
    }

    // 2. Try by {Artist} - {Title}.ext (Go backend video naming)
    if ((track.name.isNotEmpty && track.artists != null && track.artists!.isNotEmpty)) {
      const invalid = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
      String sanitize(String s) {
        var r = s;
        for (final ch in invalid) { r = r.replaceAll(ch, '_'); }
        r = r.replaceAll(RegExp(r'[. ]+$'), '');
        return r.isEmpty ? 'unknown' : r;
      }
      final stem = '${sanitize(track.artists!)} - ${sanitize(track.name)}';
      for (final ext in videoExts) {
        final path = '$downloadPath\\$stem.$ext';
        if (File(path).existsSync()) {
          return 'file://${path.replaceAll('\\', '/')}';
        }
      }
    }

    return null;
  }

  Future<void> _toggleVideo(FeedItem track, String? downloadPath) async {
    if (!_showVideo) {
      String? videoUrl = sl<PlayerCubit>().preloadedVideoUrl;
      videoUrl ??= _resolveLocalVideoUrl(track, downloadPath);
      videoUrl ??= await sl<PlayerCubit>().downloadVideoToTemp(track);
      if (videoUrl == null) return;
      await _videoPlayer.setVolume(0.0);
      try {
        await _videoPlayer.open(Media(videoUrl));
        await _videoPlayer.play();
        setState(() { _showVideo = true; _hasVideo = true; });
      } catch (_) {}
    } else {
      _stopVideoForCover();
    }
  }

  /// Switches back to the static cover (used by the little image pill on the
  /// video corner): stops the clip. The videocam button stays visible because
  /// the video is still preloaded for this track.
  void _stopVideoForCover() {
    _videoPlayer.stop();
    setState(() => _showVideo = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;

    // Proveemos los cubits via MultiBlocProvider.value porque NowPlayingPage
    // se renderiza como ruta separada de GoRouter y no hereda los BlocProviders
    // del HomePage. Los cubits se obtienen desde el container GetIt (sl).
    return MultiBlocProvider(
      providers: [
        BlocProvider<QueueCubit>.value(value: sl<QueueCubit>()),
        BlocProvider<PlayerCubit>.value(value: sl<PlayerCubit>()),
        BlocProvider<LikeCubit>.value(value: sl<LikeCubit>()),
      ],
      child: BlocBuilder<QueueCubit, QueueState>(
        builder: (context, queue) {
          if (!queue.hasCurrent) {
            return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(backgroundColor: Colors.transparent),
              body: const Center(child: Text('No track selected')),
            );
          }

          final track = queue.current!;

          return BlocBuilder<PlayerCubit, AudioPlayerState>(
            builder: (context, player) {
              final resolvedCover = context.read<LikeCubit>().resolveCoverFor(track);
              final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
              final active = isDark ? Colors.white : Colors.black;
              final page = Scaffold(
                // The page owns its opaque theme background; the blurred album
                // art is layered inside the body, underneath everything else.
                backgroundColor: bgColor,
                extendBodyBehindAppBar: true,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: active, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active,
                      fontWeight: FontWeight.w600,
                      fontSize: r.subtitleSize,
                    ),
                  ),
                  centerTitle: true,
                  actions: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.queue_music_rounded,
                            color: active.withValues(alpha: 0.7),
                          ),
                          onPressed: () => showQueueModal(context),
                        ),
                        if (queue.tracks.length > 1)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              decoration: BoxDecoration(
                                color: glowColor,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${queue.tracks.length}',
                                style: TextStyle(
                                  color: isDark ? Colors.black : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.share_rounded, color: active.withValues(alpha: 0.7)),
                      onPressed: () {
                        final text = track.albumName != null
                            ? '🎵 ${track.name} — ${track.artists ?? ''}\n💿 ${track.albumName}'
                            : '🎵 ${track.name} — ${track.artists ?? ''}';
                        SharePlus.instance.share(ShareParams(text: text));
                      },
                    ),
                  ],
                ),
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Blurred album art filling the whole screen (theme-tinted,
                    // no brand-green background color).
                    _AmbientBackdrop(
                      coverUrl: resolvedCover,
                      isDark: isDark,
                      bgColor: bgColor,
                    ),
                    SafeArea(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                        child: Column(
                          children: [
                            const Spacer(flex: 1),
                            // ── Cover / Video area ────────────────────────
                            // Lyrics now open in their own modal (lyrics_sheet),
                            // so the square always shows the cover or video.
                            _coverOrVideoArea(context, r, isDark, track, resolvedCover),
                            const Spacer(flex: 1),
                            // ── Track metadata ───────────────────────────
                            Text(
                              track.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: r.titleSize,
                                fontWeight: FontWeight.bold,
                                color: active,
                              ),
                            ),
                            SizedBox(height: r.spacingXS),
                            Text(
                              track.artists ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: r.subtitleSize,
                                color: active.withValues(alpha: 0.6),
                              ),
                            ),
                            if (_metaSubtitle(track) != null) ...[
                              SizedBox(height: r.spacingXS),
                              Text(
                                _metaSubtitle(track)!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: r.footerSize,
                                  letterSpacing: 0.2,
                                  color: active.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                            const Spacer(flex: 1),
                            _seekBar(context, r, isDark, player),
                            SizedBox(height: r.spacingM),
                            _controls(context, r, isDark, queue),
                            SizedBox(height: r.spacingL),
                            // Playback speed selector (was the volume row).
                            _speedControl(context, r, isDark, player),
                            SizedBox(height: r.spacingXL),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );

              // Swipe the whole page down to dismiss it.
              return ValueListenableBuilder<double>(
                valueListenable: _dragOffset,
                child: page,
                builder: (context, dy, child) {
                  final height = MediaQuery.sizeOf(context).height;
                  final clamped = dy < 0 ? 0.0 : dy;
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: Opacity(
                      opacity: _dragOpacity(clamped, height),
                      child: Transform.translate(
                        offset: Offset(0, clamped),
                        child: child,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }


  Widget _coverOrVideoArea(
    BuildContext context,
    Responsive r,
    bool isDark,
    FeedItem track,
    String? resolvedCover,
  ) {
    // Cover side: 76% of screen width for a premium feel, capped at 420px.
    final side = (r.width * 0.76).clamp(0.0, 420.0);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          if (_hasVideo) {
            _toggleVideo(track, context.read<PlayerCubit>().downloadPath);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.30),
                blurRadius: 44,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              width: side,
              height: side,
              child: _showVideo
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Video(controller: _videoController!, fill: Colors.transparent, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _stopVideoForCover,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.image, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        // Same widget position across track changes lets
                        // CachedNetworkImage keep the previous art visible
                        // until the new cover is decoded (no flash / blank).
                        CoverImage(
                          coverUrl: resolvedCover,
                          localPath: null,
                          width: side,
                          height: side,
                        ),
                        if (_hasVideo)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => _toggleVideo(track, context.read<PlayerCubit>().downloadPath),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.videocam, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seekBar(BuildContext context, Responsive r, bool isDark, AudioPlayerState player) {
    final duration = player.duration;
    final position = player.position;
    final remaining = duration - position;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: isDark ? AppColors.greenBright : AppColors.greenMedium,
            inactiveTrackColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
            thumbColor: isDark ? AppColors.greenBright : AppColors.greenMedium,
            overlayColor: (isDark ? AppColors.greenBright : AppColors.greenMedium).withValues(alpha: 0.15),
          ),
          child: Slider(
            value: player.progress.clamp(0.0, 1.0),
            onChanged: (v) => sl<PlayerCubit>().seekToProgress(v),
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
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                ),
              ),
              Text(
                '-${_formatDuration(remaining)}',
                style: TextStyle(
                  fontSize: r.footerSize,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _controls(BuildContext context, Responsive r, bool isDark, QueueState queue) {
    final player = context.read<PlayerCubit>().state;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final muted = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45);
    final active = isDark ? Colors.white : Colors.black;
    final track = queue.current!;
    final iconM = r.subtitleSize + 4;   // medium side icons
    final iconL = r.subtitleSize + 9;   // prev/next icons
    final gap = r.spacingL;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Like — rebuilt whenever LikeCubit changes so the heart is always in
        // sync with the liked state (across sources, via ISRC/id matching).
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
        // Shuffle
        GestureDetector(
          onTap: () { Haptic.tap(); sl<QueueCubit>().toggleShuffle(); },
          child: Icon(
            queue.shuffle ? Icons.shuffle_rounded : Icons.shuffle,
            color: queue.shuffle ? glowColor : muted,
            size: iconM,
          ),
        ),
        SizedBox(width: gap),
        // Previous
        GestureDetector(
          onTap: () { Haptic.tap(); sl<QueueCubit>().previous(); },
          child: Icon(Icons.skip_previous_rounded, color: active, size: iconL),
        ),
        SizedBox(width: gap),
        // Play/Pause — hero button
        GestureDetector(
          onTap: () { Haptic.medium(); sl<PlayerCubit>().togglePlayPause(); },
          child: Container(
            width: r.subtitleSize + 34,
            height: r.subtitleSize + 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [glowColor, glowColor.withValues(alpha: 0.7)],
              ),
              boxShadow: [
                BoxShadow(color: glowColor.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 2),
              ],
            ),
            child: player.playbackState == PlayerPlaybackState.buffering
                ? Center(
                    child: SizedBox(
                      width: r.subtitleSize + 2,
                      height: r.subtitleSize + 2,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(active),
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
        // Next
        GestureDetector(
          onTap: () { Haptic.tap(); sl<QueueCubit>().next(); },
          child: Icon(Icons.skip_next_rounded, color: active, size: iconL),
        ),
        SizedBox(width: gap),
        // Repeat
        GestureDetector(
          onTap: () { Haptic.tap(); sl<QueueCubit>().cycleRepeatMode(); },
          child: Icon(
            _repeatIcon(queue.repeatMode),
            color: queue.repeatMode != RepeatMode.none ? glowColor : muted,
            size: iconM,
          ),
        ),
        // Secondary toggles (lyrics / video) — plain icons to keep the row slim.
        // The lyrics button is always present: it opens the karaoke modal from
        // the preloaded LRC, or fetches it on the fly when needed.
        SizedBox(width: r.spacingS),
        GestureDetector(
          onTap: _lyricsLoading ? null : () => _toggleLyrics(context),
          child: _lyricsLoading
              ? SizedBox(
                  width: r.subtitleSize + 2,
                  height: r.subtitleSize + 2,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: glowColor,
                  ),
                )
              : Icon(
                  Icons.lyrics_outlined,
                  color: muted,
                  size: r.subtitleSize + 2,
                ),
        ),
        // Video toggle appears only once the clip finished preloading (it is
        // resolved in the background after the track starts playing).
        if (_hasVideo) ...[
          SizedBox(width: r.spacingS),
          GestureDetector(
            onTap: () => _videoToggleQuick(context),
            child: Icon(
              _showVideo ? Icons.image_outlined : Icons.videocam_outlined,
              color: _showVideo ? glowColor : muted,
              size: r.subtitleSize + 2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _speedControl(BuildContext context, Responsive r, bool isDark, AudioPlayerState player) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final active = isDark ? Colors.white : Colors.black;
    final inactive = active.withValues(alpha: 0.4);
    final accent = isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.speed_rounded, size: r.subtitleSize, color: inactive),
            SizedBox(width: r.spacingS),
            Text(
              'Speed',
              style: TextStyle(
                fontSize: r.footerSize,
                letterSpacing: 0.4,
                color: inactive,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => sl<PlayerCubit>().setRate(1.0),
              child: Text(
                player.rate == 1.0 ? '1.0×' : '${player.rate.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}×',
                style: TextStyle(
                  fontSize: r.footerSize,
                  fontWeight: FontWeight.w600,
                  color: player.rate == 1.0 ? active : inactive,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.spacingXS),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final s in speeds) ...[
              if (s != speeds.first) const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => sl<PlayerCubit>().setRate(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: (player.rate == s ? accent : Colors.transparent)
                          .withValues(alpha: player.rate == s ? 0.22 : 0.0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: player.rate == s
                            ? accent.withValues(alpha: 0.6)
                            : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      '${s.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}×',
                      style: TextStyle(
                        fontSize: r.footerSize - 1,
                        fontWeight: player.rate == s ? FontWeight.w700 : FontWeight.w500,
                        color: player.rate == s ? accent : inactive,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _videoToggleQuick(BuildContext context) {
    if (_showVideo) {
      _stopVideoForCover();
      return;
    }
    final queue = context.read<QueueCubit>().state;
    if (!queue.hasCurrent || queue.current == null) return;
    _toggleVideo(queue.current!, context.read<PlayerCubit>().downloadPath);
  }

  IconData _repeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.none:
        return Icons.repeat_rounded;
      case RepeatMode.one:
        return Icons.repeat_one_rounded;
      case RepeatMode.all:
        return Icons.repeat_rounded;
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Blurred album-art backdrop that fills the whole page.
///
/// Respects the theme strictly: in dark mode a strong black veil keeps the
/// screen dark (white text readable); in light mode a white veil keeps it
/// light (black text readable). No brand-green tint is applied here.
class _AmbientBackdrop extends StatelessWidget {
  final String? coverUrl;
  final bool isDark;
  final Color bgColor;

  const _AmbientBackdrop({
    required this.coverUrl,
    required this.isDark,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty) ...[
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Transform.scale(
                  scale: 1.25,
                  child: imageFromUrl(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          ] else
            ColoredBox(color: bgColor),
          // Theme veil — keeps the page genuinely dark / light.
          ColoredBox(color: bgColor.withValues(alpha: isDark ? 0.66 : 0.42)),
          // Extra bottom dim so seek bar + controls stay readable.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  bgColor.withValues(alpha: isDark ? 0.35 : 0.25),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
