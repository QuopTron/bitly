import 'dart:async';
import 'dart:io';
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
import '../../shared/theme/app_colors.dart';
import '../../../injection.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/glass_container.dart';
import 'queue_modal.dart';

class _LrcLine {
  final Duration time;
  final String text;
  const _LrcLine(this.time, this.text);
}

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  bool _showVideo = false;
  bool _showLyrics = false;
  final Player _videoPlayer = Player();
  VideoController? _videoController;
  StreamSubscription? _queueSub;
  String? _lyricsText;
  bool _hasVideo = false;

  /// Parsed LRC lines for karaoke sync.
  final List<_LrcLine> _lrcLines = [];
  final ScrollController _lyricsScroll = ScrollController();
  int _currentLyricIndex = -1;

  @override
  void initState() {
    super.initState();
    _videoController = VideoController(_videoPlayer);
    // Reset video/lyrics when track changes
    _queueSub = sl<QueueCubit>().stream.listen((queueState) {
      _hasVideo = false;
      if (_showVideo) {
        _videoPlayer.stop();
        setState(() => _showVideo = false);
      }
      _showLyrics = false;
      _lyricsText = null;
      _lrcLines.clear();
      _currentLyricIndex = -1;
    });
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    _videoPlayer.dispose();
    _lyricsScroll.dispose();
    super.dispose();
  }

  List<_LrcLine> _parseLrc(String lrc) {
    final lines = lrc.split('\n');
    final result = <_LrcLine>[];
    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');
    for (final raw in lines) {
      final trimmed = raw.trim();
      final match = timeRegex.firstMatch(trimmed);
      if (match == null) continue;
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final millis = int.parse(match.group(3)!.padRight(3, '0'));
      final time = Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
      final text = trimmed.replaceAll(timeRegex, '').trim();
      if (text.isNotEmpty) result.add(_LrcLine(time, text));
    }
    return result;
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
      String? videoUrl = _resolveLocalVideoUrl(track, downloadPath);
      videoUrl ??= await sl<PlayerCubit>().downloadVideoToTemp(track);
      if (videoUrl == null) return;
      await _videoPlayer.setVolume(0.0);
      try {
        await _videoPlayer.open(Media(videoUrl));
        await _videoPlayer.play();
        setState(() { _showVideo = true; _hasVideo = true; });
      } catch (_) {}
    } else {
      await _videoPlayer.stop();
      setState(() => _showVideo = false);
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
              return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white : Colors.black, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(
                  track.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: r.subtitleSize,
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: Icon(Icons.queue_music_rounded, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7)),
                    onPressed: () => showQueueModal(context),
                  ),
                  IconButton(
                    icon: Icon(Icons.share_rounded, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7)),
                    onPressed: () {
                      final text = track.albumName != null
                          ? '🎵 ${track.name} — ${track.artists ?? ''}\n💿 ${track.albumName}'
                          : '🎵 ${track.name} — ${track.artists ?? ''}';
                      SharePlus.instance.share(ShareParams(text: text));
                    },
                  ),
                ],
              ),
              body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor,
                    bgColor,
                    (isDark ? AppColors.greenBright : AppColors.greenMedium).withValues(alpha: 0.04),
                    bgColor,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                  child: Column(
                    children: [
                      const Spacer(flex: 1),
                      // ── Cover / Video / Lyrics area ──────────────────────
                      if (_showLyrics && _lrcLines.isNotEmpty)
                        _karaokeLyrics(r, isDark, player)
                      else if (_showLyrics && _lyricsText != null)
                        _plainLyrics(r, isDark)
                      else
                        _coverOrVideoArea(context, r, isDark, track, resolvedCover),
                      // ── Toggle hints ──────────────────────────────────────
                      if (_showVideo)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Tap cover to show video',
                            style: TextStyle(
                              fontSize: r.footerSize - 1,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      if (_showLyrics && _lyricsText != null && !_showLyrics)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Tap cover to show lyrics',
                            style: TextStyle(
                              fontSize: r.footerSize - 1,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      const Spacer(flex: 1),
                      Text(
                        track.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: r.titleSize,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      SizedBox(height: r.spacingXS),
                      Text(
                        track.artists ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: r.subtitleSize,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                        ),
                      ),
                      const Spacer(flex: 1),
                      _seekBar(context, r, isDark, player),
                      SizedBox(height: r.spacingM),
                      _controls(context, r, isDark, queue),
                      SizedBox(height: r.spacingL),
                      _volumeSlider(context, r, player),
                      SizedBox(height: r.spacingXL),
                    ],
                  ),
                ),
              ),
            ),
            );
          },
        );
      },
    ),
  );
  }

  Widget _karaokeLyrics(Responsive r, bool isDark, AudioPlayerState player) {
    final pos = player.position;
    int activeIdx = _lrcLines.length - 1;
    for (int i = _lrcLines.length - 1; i >= 0; i--) {
      if (pos >= _lrcLines[i].time) { activeIdx = i; break; }
    }
    if (activeIdx != _currentLyricIndex && _lyricsScroll.hasClients) {
      _currentLyricIndex = activeIdx;
      final offset = (activeIdx - 2).clamp(0, _lrcLines.length - 1) * 40.0;
      _lyricsScroll.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: r.width * 0.7,
        height: r.width * 0.7,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: GestureDetector(
          onTap: () => setState(() => _showLyrics = false),
          child: ListView.builder(
            controller: _lyricsScroll,
            itemCount: _lrcLines.length,
            itemExtent: 40,
            itemBuilder: (context, i) {
              final isActive = i == activeIdx;
              return AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: isActive ? r.footerSize + 2 : r.footerSize,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? (isDark ? AppColors.greenBright : AppColors.greenMedium)
                      : (isDark ? Colors.white70 : Colors.black54),
                  height: 1.4,
                ),
                child: Text(
                  _lrcLines[i].text,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _plainLyrics(Responsive r, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: r.width * 0.7,
        height: r.width * 0.7,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => setState(() => _showLyrics = false),
          child: SingleChildScrollView(
            child: Text(
              _stripLrcTimestamps(_lyricsText!),
              style: TextStyle(
                fontSize: r.footerSize,
                height: 1.6,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _coverOrVideoArea(BuildContext context, Responsive r, bool isDark, FeedItem track, String? resolvedCover) {
    // Cover side: 75% of screen width for a premium feel, capped at 420px.
    final side = (r.width * 0.75).clamp(0.0, 420.0);
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: GestureDetector(
        onTap: () {
          if (_hasVideo) {
            _toggleVideo(track, context.read<PlayerCubit>().downloadPath);
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: side,
            height: side,
            child: _showVideo
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Video(controller: _videoController!, fill: Colors.transparent, fit: BoxFit.cover),
                    if (!_showLyrics)
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _showVideo = false),
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
                    CoverImage(
                      coverUrl: resolvedCover, localPath: null,
                      width: side, height: side,
                    ),
                    if (_hasVideo && !_showVideo)
                      Positioned(
                        top: 8, right: 8,
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
                ), // Stack
              ), // SizedBox
        ), // ClipRRect
      ), // GestureDetector
      ), // Container glow
    ); // RepaintBoundary
  }

  Widget _seekBar(BuildContext context, Responsive r, bool isDark, AudioPlayerState player) {
    final duration = player.duration;
    final position = player.position;
    final remaining = duration - position;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: isDark ? AppColors.greenBright : AppColors.greenMedium,
            inactiveTrackColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
            thumbColor: isDark ? AppColors.greenBright : AppColors.greenMedium,
            overlayColor: (isDark ? AppColors.greenBright : AppColors.greenMedium).withValues(alpha: 0.2),
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
                style: TextStyle(fontSize: r.footerSize, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5)),
              ),
              Text(
                '-${_formatDuration(remaining)}',
                style: TextStyle(fontSize: r.footerSize, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5)),
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
    final muted = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5);
    final active = isDark ? Colors.white : Colors.black;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            queue.shuffle ? Icons.shuffle : Icons.shuffle_on_rounded,
            color: queue.shuffle ? glowColor : muted,
          ),
          iconSize: r.subtitleSize + 4,
          onPressed: () => sl<QueueCubit>().toggleShuffle(),
        ),
        SizedBox(width: r.spacingL),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          color: active,
          iconSize: r.subtitleSize + 10,
          onPressed: () => sl<QueueCubit>().previous(),
        ),
        SizedBox(width: r.spacingL),
        GlassContainer(
          borderRadius: 30,
          bgColor: glowColor.withValues(alpha: 0.2),
          borderColor: glowColor.withValues(alpha: 0.1),
          padding: const EdgeInsets.all(4),
          child: IconButton(
            icon: player.playbackState == PlayerPlaybackState.buffering
                ? SizedBox(
                    width: r.subtitleSize - 2,
                    height: r.subtitleSize - 2,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(glowColor),
                    ),
                  )
                : Icon(
                    player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: glowColor,
                  ),
            iconSize: r.subtitleSize + 16,
            onPressed: () => sl<PlayerCubit>().togglePlayPause(),
          ),
        ),
        SizedBox(width: r.spacingL),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          color: active,
          iconSize: r.subtitleSize + 10,
          onPressed: () => sl<QueueCubit>().next(),
        ),
        SizedBox(width: r.spacingL),
        IconButton(
          icon: Icon(
            _repeatIcon(queue.repeatMode),
            color: queue.repeatMode != RepeatMode.none ? glowColor : muted,
          ),
          iconSize: r.subtitleSize + 4,
          onPressed: () => sl<QueueCubit>().cycleRepeatMode(),
        ),
        if (_lyricsText != null || sl<PlayerCubit>().preloadedLyrics != null) ...[
          SizedBox(width: r.spacingS),
          IconButton(
            icon: Icon(
              Icons.lyrics,
              color: _showLyrics ? glowColor : muted,
            ),
            iconSize: r.subtitleSize + 4,
            onPressed: () => _toggleLyrics(),
          ),
        ],
        if (_hasVideo) ...[
          SizedBox(width: r.spacingS),
          IconButton(
            icon: Icon(
              _showVideo ? Icons.image : Icons.videocam,
              color: _showVideo ? glowColor : muted,
            ),
            iconSize: r.subtitleSize + 4,
            onPressed: () => _videoToggleQuick(context),
          ),
        ],
      ],
    );
  }

  Widget _volumeSlider(BuildContext context, Responsive r, AudioPlayerState player) {
    return Row(
      children: [
        Icon(Icons.volume_down_rounded, size: r.subtitleSize, color: Colors.grey),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.grey,
              inactiveTrackColor: Colors.grey.withValues(alpha: 0.2),
              thumbColor: Colors.grey,
            ),
            child: Slider(
              value: player.volume,
              onChanged: (v) => sl<PlayerCubit>().setVolume(v),
            ),
          ),
        ),
        Icon(Icons.volume_up_rounded, size: r.subtitleSize, color: Colors.grey),
      ],
    );
  }

  void _videoToggleQuick(BuildContext context) {
    if (_showVideo) {
      _videoPlayer.stop();
      setState(() => _showVideo = false);
      return;
    }
    final preloadedUrl = sl<PlayerCubit>().preloadedVideoUrl;
    if (preloadedUrl != null) {
      _videoPlayer.setVolume(0.0);
      _videoPlayer.open(Media(preloadedUrl)).then((_) => _videoPlayer.play());
      setState(() { _showVideo = true; _hasVideo = true; });
    } else {
      final queue = context.read<QueueCubit>().state;
      if (queue.hasCurrent && queue.current != null) {
        _toggleVideo(queue.current!, context.read<PlayerCubit>().downloadPath);
      }
    }
  }

  void _toggleLyrics() {
    if (_showLyrics) {
      setState(() => _showLyrics = false);
      return;
    }
    final preloaded = sl<PlayerCubit>().preloadedLyrics;
    if (preloaded != null && preloaded != _lyricsText) {
      _lrcLines
        ..clear()
        ..addAll(_parseLrc(preloaded));
      setState(() { _lyricsText = preloaded; _showLyrics = true; });
    } else {
      setState(() => _showLyrics = !_showLyrics);
    }
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

  /// Strips LRC timestamps from lyrics, returning only plain text lines.
  String _stripLrcTimestamps(String lrc) {
    final lines = lrc.split('\n');
    return lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return false;
      // Skip metadata tags like [ti:...], [ar:...], [by:...], etc.
      if (RegExp(r'^\[(ti|ar|al|by|offset|re|ve):').hasMatch(trimmed)) return false;
      // Keep lines that are not purely timestamps
      return !RegExp(r'^\[\d{2}:\d{2}\.\d{2,3}\]$').hasMatch(trimmed);
    }).map((line) {
      // Remove all [mm:ss.xx] timestamps from the line
      return line.replaceAll(RegExp(r'\[\d{2}:\d{2}\.\d{2,3}\]'), '').trim();
    }).where((line) => line.isNotEmpty).join('\n');
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}


