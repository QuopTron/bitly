import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/utils/responsive.dart';
import '../../shared/models/feed_models.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../backend/services/connectivity_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../../injection.dart';
import '../../shared/widgets/cover_image.dart';
import 'queue_modal.dart';
import 'lyrics_sheet.dart';
import 'now_playing/seek_bar.dart';
import 'now_playing/player_controls.dart';
import 'now_playing/speed_control.dart';
import 'now_playing/cover_or_video_area.dart';
import 'now_playing/video_backdrop_texture.dart';
import '../../shared/models/performance_profile.dart';

/// Remembers the cover/video choice of the last full-player session so
/// minimizing the player (swipe-down / back) and reopening it for the SAME
/// track restores the mode the user left it in — video stays video, cover
/// stays cover — instead of always starting over on the cover.
class _VideoSession {
  static String? trackKey;
  static String? url;
  static bool enabled = false;
}

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage>
    with SingleTickerProviderStateMixin {
  bool _showVideo = false;
  bool _videoLoading = false;
  final Player _videoPlayer = Player();
  VideoController? _videoController;
  StreamSubscription? _queueSub;
  StreamSubscription<void>? _videoCompSub;
  /// Set while the visualizer is playing so the completion handler restarts it
  /// instead of leaving the last frame frozen on screen.
  bool _videoLoopArmed = false;
  bool _hasVideo = false;

  /// True while a lyrics fetch triggered from the controls is in flight — the
  /// lyrics button shows a tiny spinner instead of silently doing nothing.
  bool _lyricsLoading = false;

  // ── Canvas video state ────────────────────────────────────────
  /// Id of the track whose video is preloaded and ready to alternate with the
  /// cover (drives the videocam button on the artwork + controls row).
  String? _videoTrackId;
  ValueNotifier<String?>? _videoReadySrc;

  /// Key of the track this page last acted on (id|source). Queue edits that
  /// don't change the current song (addNext, autoplay append, reorder) no
  /// longer kill an active visualizer — only real track changes do.
  String? _lastQueueKey;

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
    // Reset video/lyrics when the track ACTUALLY changes. Queue edits that
    // keep the same current track (addNext, autoplay append, reorder) must
    // not stop a visualizer that's playing.
    _queueSub = sl<QueueCubit>().stream.listen((queueState) {
      final key = queueState.hasCurrent
          ? '${queueState.current!.id}|${queueState.current!.source}'
          : null;
      if (key == _lastQueueKey) return;
      _lastQueueKey = key;
      _hasVideo = false;
      _videoLoopArmed = false;
      _VideoSession.enabled = false;
      _VideoSession.url = null;
      _VideoSession.trackKey = null;
      if (_showVideo) {
        _videoPlayer.stop();
        setState(() => _showVideo = false);
      }
      // A lyrics modal, if open, follows the new current track on its own;
      // here we only reset our loading flag for the controls-row spinner.
      _lyricsLoading = false;
      _videoTrackId = null;
      // Re-evaluate the video/visualizer toggle for the new track (needs a
      // moment to check the local downloads + network state).
      _refreshVideoAvailability();
    });
    // When the background video finishes preloading, we only flip the
    // videocam button visible on the cover — the user alternates manually.
    _videoReadySrc = sl<PlayerCubit>().preloadedVideoReady
      ..addListener(_onVideoReadyChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onVideoReadyChanged());
    // Restore the cover/video mode this page was left in for the same song
    // (minimized the player while the visualizer was on → reopen in video).
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreVideoSession());
  }

  @override
  void dispose() {
    _videoReadySrc?.removeListener(_onVideoReadyChanged);
    _queueSub?.cancel();
    _videoCompSub?.cancel();
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
    // Even when nothing is preloaded yet, the visualizer is still offered
    // when the device is online (fetched on demand on tap) or when a video
    // was already downloaded for this song. Re-check asynchronously so the
    // icon doesn't need a successful preload to appear.
    _refreshVideoAvailability();
  }

  /// Smart video/visualizer availability: the toggle is offered when the
  /// preloaded video is ready, a local video was downloaded, or the device
  /// has a network connection (the video is then fetched on demand). Only
  /// when offline AND nothing downloaded does the icon stay hidden.
  Future<void> _refreshVideoAvailability() async {
    if (!mounted) return;
    final cubit = sl<PlayerCubit>();
    final queue = sl<QueueCubit>().state;
    if (!queue.hasCurrent) return;
    final track = queue.current!;
    // Guard against racing the track that was current when the check started.
    final checkKey = '${track.id}|${track.source}';
    final preloaded = cubit.preloadedVideoReady.value;
    final ready = preloaded != null && preloaded.isNotEmpty;
    final downloaded =
        resolveLocalVideoUrl(track, cubit.downloadPath) != null;
    if (ready || downloaded) {
      if (mounted && _hasVideo != true) setState(() => _hasVideo = true);
      return;
    }
    final online = await ConnectivityService.isOnline();
    if (!mounted) return;
    final cur = sl<QueueCubit>().state;
    if (!cur.hasCurrent ||
        '${cur.current!.id}|${cur.current!.source}' != checkKey) {
      return; // track changed while we awaited the network check
    }
    if (_hasVideo != online) setState(() => _hasVideo = online);
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
                          onPressed: () => showQueueModal(
                            context,
                            showVideo: _showVideo,
                            videoController: _videoController,
                          ),
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
                    // no brand-green background color). When the visualizer
                    // video is playing, the SAME video becomes the backdrop
                    // everywhere the cover would be — the state is either
                    // cover or video, everywhere.
                    _AmbientBackdrop(
                      coverUrl: resolvedCover,
                      isDark: isDark,
                      bgColor: bgColor,
                      showVideo: _showVideo,
                      videoController: _videoController,
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
    return CoverOrVideoArea(
      track: track,
      resolvedCover: resolvedCover,
      isDark: isDark,
      showVideo: _showVideo,
      hasVideo: _hasVideo,
      videoLoading: _videoLoading,
      videoController: _videoController,
      onToggleVideo: () => _toggleVideo(track, context.read<PlayerCubit>().downloadPath),
      onStopVideo: _stopVideoForCover,
    );
  }

  Future<void> _toggleVideo(FeedItem track, String? downloadPath) async {
    if (_showVideo) {
      _stopVideoForCover();
      return;
    }
    if (_videoLoading) return;
    setState(() => _videoLoading = true);
    try {
      String? videoUrl = sl<PlayerCubit>().preloadedVideoUrl;
      videoUrl ??= resolveLocalVideoUrl(track, downloadPath);
      if (videoUrl == null) {
        // Not preloaded and no local file — fetch on demand only when online.
        if (!await ConnectivityService.isOnline()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sin conexión y sin video descargado'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
        // Fast path: resolve a DIRECT streamable visualizer URL through the
        // InnerTube route — mpv then loads the video progressively (by
        // sections) so frames appear in ~1-2s instead of waiting for a full
        // file download.
        videoUrl = await sl<PlayerCubit>().resolveVisualizerUrl(track);
        // Fallback: full download-to-cache pipeline (works offline afterwards).
        videoUrl ??= await sl<PlayerCubit>().downloadVideoToTemp(track);
      }
      if (videoUrl == null || videoUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener el video visualizer'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      try {
        // The visualizer runs in a loop until the song ends or the user
        // switches back to the cover. media_kit's playlist loop can stop on
        // HTTP streams, so also restart from the completion event.
        _armVideoLoopSubscription();
        await _videoPlayer.setPlaylistMode(PlaylistMode.loop);
        await _videoPlayer.open(Media(videoUrl));
        await _videoPlayer.play();
        // Mute AFTER open: mpv resets the volume on every open(), so setting
        // it before would be wiped and the visualizer's own audio would play
        // over the song. This is a pure visualizer — zero audio contribution.
        await _videoPlayer.setVolume(0.0);
        if (!mounted) return;
        _videoLoopArmed = true;
        // Remember the mode so reopening the player (after minimize) restores
        // video for this same track instead of falling back to the cover.
        _VideoSession.trackKey = '${track.id}|${track.source}';
        _VideoSession.url = videoUrl;
        _VideoSession.enabled = true;
        setState(() { _showVideo = true; _hasVideo = true; });
      } catch (_) {
        _VideoSession.enabled = false;
        _VideoSession.url = null;
        _VideoSession.trackKey = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo reproducir el video visualizer'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _videoLoading = false);
    }
  }

  /// Loop-restart listener for the visualizer: shared by the toggle and the
  /// session restore so both behave identically.
  void _armVideoLoopSubscription() {
    _videoCompSub ??= _videoPlayer.stream.completed.listen((_) {
      // Loop: jump back to the start instead of freezing on the last frame
      // (or letting the page think the visualizer ended).
      if (!_videoLoopArmed || !mounted) return;
      _videoPlayer.seek(Duration.zero);
      _videoPlayer.play();
    });
  }

  /// Reopens the player already in video mode when the user minimized it while
  /// the visualizer was on (same track). Kept fire-and-forget: if the stored
  /// URL is dead by now it just falls back to the cover with a snackbar.
  Future<void> _restoreVideoSession() async {
    if (!mounted || !_VideoSession.enabled || _VideoSession.url == null) {
      return;
    }
    final queue = sl<QueueCubit>().state;
    if (!queue.hasCurrent) return;
    final key = '${queue.current!.id}|${queue.current!.source}';
    if (_VideoSession.trackKey != key) return;
    final url = _VideoSession.url!;
    _lastQueueKey = key;
    setState(() {
      _hasVideo = true;
      _videoLoading = true;
    });
    try {
      _armVideoLoopSubscription();
      await _videoPlayer.setPlaylistMode(PlaylistMode.loop);
      await _videoPlayer.open(Media(url));
      await _videoPlayer.play();
      await _videoPlayer.setVolume(0.0);
      if (!mounted) return;
      _videoLoopArmed = true;
      setState(() => _showVideo = true);
    } catch (_) {
      _VideoSession.enabled = false;
      _VideoSession.url = null;
      _VideoSession.trackKey = null;
      if (mounted) setState(() {
        _showVideo = false;
        _hasVideo = false;
      });
    } finally {
      if (mounted) setState(() => _videoLoading = false);
    }
  }

  void _stopVideoForCover() {
    _videoLoopArmed = false;
    _VideoSession.enabled = false;
    _VideoSession.url = null;
    _VideoSession.trackKey = null;
    _videoPlayer.stop();
    if (mounted) setState(() => _showVideo = false);
  }

  Widget _seekBar(BuildContext context, Responsive r, bool isDark, AudioPlayerState player) {
    return SeekBar(r: r, isDark: isDark, player: player);
  }

  Widget _controls(BuildContext context, Responsive r, bool isDark, QueueState queue) {
    final track = queue.current!;
    return PlayerControls(
      r: r, isDark: isDark, queue: queue, track: track,
      lyricsLoading: _lyricsLoading,
      onToggleLyrics: () => _toggleLyrics(context),
    );
  }

  Widget _speedControl(BuildContext context, Responsive r, bool isDark, AudioPlayerState player) {
    return SpeedControl(r: r, isDark: isDark, player: player);
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
  final bool showVideo;
  final VideoController? videoController;

  const _AmbientBackdrop({
    required this.coverUrl,
    required this.isDark,
    required this.bgColor,
    this.showVideo = false,
    this.videoController,
  });

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showVideo && videoController != null)
            // The visualizer video IS the background (no per-frame blur — a
            // full-screen blurred live video would repaint offscreen every
            // frame; the theme veil below keeps the UI readable instead). It
            // mirrors the SAME texture the cover square is playing so there's
            // a single native output but two places render it.
            VideoBackdropTexture(controller: videoController!)
          else if (url != null && url.isNotEmpty) ...[
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: backdropBlurSigma,
                  sigmaY: backdropBlurSigma,
                ),
                child: Transform.scale(
                  scale: 1.25,
                  child: imageFromUrl(
                    url,
                    fit: BoxFit.cover,
                    // Bounded decode — blur masks detail anyway.
                    width: 512,
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
