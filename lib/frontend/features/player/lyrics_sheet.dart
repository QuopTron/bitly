import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../shared/models/feed_models.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../injection.dart';
import '../../shared/models/performance_profile.dart';
import '../../shared/utils/responsive.dart';
import '../../shared/utils/cover_palette.dart';
import '../../shared/widgets/cover_image.dart';

class _KLine {
  final Duration time;
  final String text;

  /// Word-level timestamps (enhanced LRC `<mm:ss.xx>word`). Empty when the
  /// source has no inline tags — the karaoke fill then falls back to a smooth
  /// uniform sweep across the line's own time span.
  final List<(Duration, String)> words;

  const _KLine(this.time, this.text, [this.words = const []]);
}

/// Opens the karaoke lyrics overlay for [lyrics] (raw LRC or plain text).
/// The active line is kept in the center of the screen and auto-scrolls with
/// the song; upcoming lines are tinted with the cover's smart palette colors.
void showLyricsSheet(
  BuildContext context, {
  required FeedItem track,
  required String lyrics,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    builder: (_) => _LyricsSheet(track: track, rawLyrics: lyrics),
  );
}

class _LyricsSheet extends StatefulWidget {
  final FeedItem track;
  final String rawLyrics;

  const _LyricsSheet({required this.track, required this.rawLyrics});

  @override
  State<_LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<_LyricsSheet> {
  final ScrollController _scroll = ScrollController();
  final List<_KLine> _lines = [];
  String _plainText = '';
  int _activeIdx = 0;
  double _viewportH = 600;
  Future<CoverPalette?>? _paletteFuture;

  @override
  void initState() {
    super.initState();
    _parse();
    _paletteFuture = paletteForCover(_resolveCover());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String? _resolveCover() {
    try {
      final current = sl<QueueCubit>().state.current;
      if (current != null) return sl<LikeCubit>().resolveCoverFor(current);
    } catch (_) {}
    return widget.track.coverUrl;
  }

  /// Parses a `mm:ss.xx` time tag into a Duration.
  Duration _parseTag(String tag) {
    final minutes = int.parse(tag.substring(0, 2));
    final seconds = int.parse(tag.substring(3, 5));
    final millis = tag.length > 6 ? int.parse(tag.substring(6).padRight(3, '0')) : 0;
    return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  void _parse() {
    final raw = widget.rawLyrics;
    _plainText = _stripLrc(raw);
    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');
    for (final rawLine in raw.split('\n')) {
      final trimmed = rawLine.trim();
      final match = timeRegex.firstMatch(trimmed);
      if (match == null) continue;
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final millis = int.parse(match.group(3)!.padRight(3, '0'));
      var text = trimmed.replaceAll(timeRegex, '').trim();
      if (text.isEmpty) continue;

      // Enhanced LRC: inline `<mm:ss.xx>word` tags → per-word karaoke.
      // Split keeps the tag values interleaved: [before, tag, word, tag, word…].
      final inlineRegex = RegExp(r'<(\d{1,2}:\d{2}(?:\.\d{1,3})?)>');
      final words = <(Duration, String)>[];
      final split = text.split(inlineRegex);
      if (split.length >= 3) {
        var firstTime = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
        for (var i = 0; i < split.length - 1; i += 2) {
          final tag = split[i + 1].trim();
          if (tag.isEmpty) continue;
          final wordText = split[i].trim();
          if (wordText.isNotEmpty) {
            words.add((firstTime, wordText));
          }
          firstTime = _parseTag(tag);
        }
        final tail = split.last.trim();
        if (tail.isNotEmpty) words.add((firstTime, tail));
        text = text.replaceAll(inlineRegex, '').trim();
      }

      _lines.add(_KLine(
        Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
        text,
        words,
      ));
    }
    if (_lines.isNotEmpty) {
      _lines.sort((a, b) => a.time.compareTo(b.time));
    }
  }

  /// Center-scrolls the active line; only when it actually changes (once per
  /// lyric, not on every position tick).
  void _syncScroll(int newIdx, double viewportH) {
    if (newIdx == _activeIdx && viewportH == _viewportH) return;
    final lineH = 56.0;
    final previous = _activeIdx;
    _activeIdx = newIdx;
    _viewportH = viewportH;
    if (newIdx == previous) return;
    if (!_scroll.hasClients) return;
    final target =
        (newIdx * lineH - viewportH / 2 + lineH / 2).clamp(0.0, double.infinity);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final height = MediaQuery.sizeOf(context).height;
    final cover = _resolveCover();

    return MultiBlocProvider(
      providers: [
        BlocProvider<PlayerCubit>.value(value: sl<PlayerCubit>()),
        BlocProvider<QueueCubit>.value(value: sl<QueueCubit>()),
      ],
      child: BlocBuilder<PlayerCubit, AudioPlayerState>(
        builder: (context, player) {
          // ── active line from the current position ────────────────
          var active = 0;
          if (_lines.isNotEmpty) {
            for (var i = _lines.length - 1; i >= 0; i--) {
              if (player.position >= _lines[i].time) { active = i; break; }
            }
          }

          final bg = isDark ? const Color(0xFF141414) : const Color(0xFFF6F6F6);

          return Container(
            // Half-screen karaoke modal (Spotify-style, doesn't cover the
            // whole player so the artwork + quick controls stay visible).
            height: (height * 0.5).clamp(340.0, height * 0.62),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Blurred cover behind the modal for the "bonito" look.
                Positioned.fill(
                  child: _coverBlur(cover, isDark),
                ),
                Positioned.fill(
                  child: Container(
                    color: (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: isDark ? 0.68 : 0.5),
                  ),
                ),
                Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: r.spacingS),
                    _header(r, isDark),
                    const SizedBox(height: 2),
                    const Divider(height: 1),
                    // Karaoke lines take the center; upcoming lines tinted
                    // with the cover palette, active line highlighted.
                    Expanded(
                      child: FutureBuilder<CoverPalette?>(
                        future: _paletteFuture,
                        builder: (context, snap) {
                          final palette = snap.data;
                          return _lines.isNotEmpty
                              ? LayoutBuilder(
                                  builder: (context, constraints) {
                                    _syncScroll(active, constraints.maxHeight);
                                    return ListView.builder(
                                      controller: _scroll,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: r.spacingXL,
                                      ),
                                      itemExtent: 56,
                                      itemCount: _lines.length,
                                      itemBuilder: (context, i) => _karaokeLine(
                                        r, isDark, i, active, palette,
                                        player.position,
                                      ),
                                    );
                                  },
                                )
                              : _plainLyrics(r, isDark);
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    // Quick controls stay reachable while singing: seek bar
                    // plus prev / play / next / repeat (bigger touch targets).
                    _transportRow(context, r, isDark, player),
                    SizedBox(height: r.spacingS),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _coverBlur(String? cover, bool isDark) {
    if (cover == null || cover.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: backdropBlurSigma,
          sigmaY: backdropBlurSigma,
        ),
        child: Transform.scale(
          scale: 1.3,
          child: imageFromUrl(
            cover,
            fit: BoxFit.cover,
            width: 512,
            height: double.infinity,
          ),
        ),
      ),
    );
  }

  Widget _header(Responsive r, bool isDark) {
    final fg = isDark ? Colors.white : Colors.black;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingL),
      child: Row(
        children: [
          Icon(
            Icons.lyrics_rounded,
            size: r.subtitleSize + 2,
            color: fg,
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.track.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: r.subtitleSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.track.artists ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.5),
                    fontSize: r.footerSize,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: fg),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Bottom quick-access row while the karaoke sheet is open: the seek bar
  /// (current / total time) plus prev / play / next / repeat — same controls
  /// as the full player, with bigger touch targets.
  Widget _transportRow(
    BuildContext context,
    Responsive r,
    bool isDark,
    AudioPlayerState player,
  ) {
    final fg = isDark ? Colors.white : Colors.black;
    final muted = fg.withValues(alpha: 0.45);
    final iconS = r.subtitleSize + 8;   // bigger icons
    final playS = r.subtitleSize + 40;
    final gap = r.spacingL + 4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingM),
          child: Row(
            children: [
              Text(
                _fmt(player.position),
                style: TextStyle(fontSize: r.footerSize, color: fg.withValues(alpha: 0.5)),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: fg.withValues(alpha: 0.7),
                    inactiveTrackColor: fg.withValues(alpha: 0.12),
                    thumbColor: fg.withValues(alpha: 0.8),
                  ),
                  child: Slider(
                    value: player.duration.inMilliseconds > 0
                        ? (player.position.inMilliseconds /
                                player.duration.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0,
                    onChangeEnd: (v) => sl<PlayerCubit>().seekToProgress(v),
                    onChanged: (_) {},
                  ),
                ),
              ),
              Text(
                _fmt(player.duration),
                style: TextStyle(fontSize: r.footerSize, color: fg.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => sl<QueueCubit>().previous(),
              child: Icon(Icons.skip_previous_rounded, color: fg, size: iconS + 4),
            ),
            SizedBox(width: gap),
            GestureDetector(
              onTap: () => sl<PlayerCubit>().togglePlayPause(),
              child: Container(
                width: playS,
                height: playS,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fg.withValues(alpha: 0.14),
                  border: Border.all(color: fg.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: fg,
                  size: playS * 0.58,
                ),
              ),
            ),
            SizedBox(width: gap),
            BlocBuilder<QueueCubit, QueueState>(
              builder: (context, queue) => GestureDetector(
                onTap: () => sl<QueueCubit>().next(),
                child: Icon(Icons.skip_next_rounded, color: fg, size: iconS + 4),
              ),
            ),
            SizedBox(width: gap),
            BlocBuilder<QueueCubit, QueueState>(
              builder: (context, queue) => GestureDetector(
                onTap: () => sl<QueueCubit>().cycleRepeatMode(),
                child: Icon(
                  queue.repeatMode == RepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: queue.repeatMode != RepeatMode.none ? fg : muted,
                  size: iconS,
                ),
              ),
            ),
            SizedBox(width: gap),
            BlocBuilder<QueueCubit, QueueState>(
              builder: (context, queue) => GestureDetector(
                onTap: () => sl<QueueCubit>().toggleShuffle(),
                child: Icon(
                  Icons.shuffle_rounded,
                  color: queue.shuffle ? fg : muted,
                  size: iconS,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.spacingS),
      ],
    );
  }

  /// Real panel color behind the text: the solid bg blended with the veil
  /// (and, when available, the blurred cover's dominant tone). Contrast math
  /// runs against THIS so lyrics stay readable on any artwork.
  Color _panelColor(bool isDark, CoverPalette? palette) {
    final bg = isDark ? const Color(0xFF141414) : const Color(0xFFF6F6F6);
    final veil = (isDark ? Colors.black : Colors.white)
        .withValues(alpha: isDark ? 0.68 : 0.5);
    // Approximate what the eye sees: bg under a veil over the cover.
    final withVeil = Color.lerp(bg, veil, 0.5)!;
    if (palette == null) return withVeil;
    return Color.lerp(withVeil, palette.dominant, isDark ? 0.30 : 0.22)!;
  }

  /// Fraction (0..1) of how far the song is through line [i]'s own time span.
  double _lineProgress(int i, Duration position) {
    final start = _lines[i].time;
    final end = i + 1 < _lines.length
        ? _lines[i + 1].time
        : start + const Duration(seconds: 4);
    final total = end - start;
    if (total <= Duration.zero) return 1.0;
    return ((position - start).inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Paints the active line with a neon karaoke fill that follows the song's
  /// seconds: sung words glow in the cover's accent, upcoming words stay dim.
  /// The line stays centered and the surrounding lines scroll around it.
  Widget _karaokeLine(
    Responsive r,
    bool isDark,
    int i,
    int active,
    CoverPalette? palette,
    Duration position,
  ) {
    final distance = i - active;
    final panelBg = _panelColor(isDark, palette);
    final fg = bestNeutral(panelBg);
    // Smart accent derived from the cover's colors, contrast-checked against
    // the REAL panel so it pops on dark AND light themes with any artwork.
    final accent = palette?.textAccent(onDarkSurface: isDark, background: panelBg) ?? fg;

    Color color;
    FontWeight weight;
    double fontSize;
    if (distance == 0) {
      color = accent;
      weight = FontWeight.bold;
      fontSize = r.titleSize + 3;
    } else if (distance > 0 && distance <= 6) {
      // Upcoming lines: cover-tinted, fading to neutral further away.
      color = palette != null
          ? palette.accentForNextLine(
              onDarkSurface: isDark, distance: distance, background: panelBg)
          : Color.lerp(
              fg.withValues(alpha: 0.55),
              accent,
              (0.72 - (distance - 1) * 0.12).clamp(0.05, 0.72),
            )!;
      weight = distance <= 2 ? FontWeight.w600 : FontWeight.w400;
      fontSize = r.subtitleSize + 4;
    } else {
      color = fg.withValues(alpha: distance < 0 ? 0.15 : 0.4);
      weight = FontWeight.w400;
      fontSize = r.subtitleSize + 1;
    }

    // ── Active line: neon karaoke sweep following the seconds ──────
    if (distance == 0) {
      final line = _lines[i];
      final progress = _lineProgress(i, position);
      final sung = fg.withValues(alpha: 0.5);   // dim, not yet sung
      final glow = accent;                       // neon, already sung
      final dimWeight = FontWeight.w500;

      // Neon glow stack: tight core + wide halo so the sung text really pops.
      final glowShadows = <Shadow>[
        Shadow(color: accent.withValues(alpha: 0.55), blurRadius: 14),
        Shadow(color: accent.withValues(alpha: 0.30), blurRadius: 26),
        Shadow(color: accent.withValues(alpha: 0.18), blurRadius: 42),
      ];

      Widget textWidget;
      if (line.words.isNotEmpty) {
        // Word-level karaoke: each word turns neon as the song reaches it.
        final spans = <TextSpan>[];
        for (final (t, w) in line.words) {
          final on = position >= t;
          final sp = TextStyle(
            color: on ? glow : sung,
            fontWeight: on ? FontWeight.w700 : dimWeight,
            shadows: on ? glowShadows : null,
          );
          if (spans.isEmpty) {
            spans.add(TextSpan(text: w, style: sp));
          } else {
            spans.add(TextSpan(text: ' $w', style: sp));
          }
        }
        textWidget = Text.rich(
          TextSpan(children: spans),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      } else {
        // No word times: sweep the fill across the line's own span.
        final painted = (line.text.length * progress).round().clamp(0, line.text.length);
        textWidget = Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: line.text.substring(0, painted),
                style: TextStyle(color: glow, fontWeight: FontWeight.w700, shadows: glowShadows),
              ),
              TextSpan(
                text: line.text.substring(painted),
                style: TextStyle(color: sung, fontWeight: dimWeight),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: fontSize,
            height: 1.1,
          ),
          child: textWidget,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 250),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1.1,
        ),
        child: Text(
          _lines[i].text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _plainLyrics(Responsive r, bool isDark) {
    final panelBg = _panelColor(isDark, null);
    final fg = bestNeutral(panelBg);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: r.spacingXL, vertical: r.spacingL),
        child: Text(
          _plainText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: fg,
            fontSize: r.footerSize + 2,
            height: 1.7,
          ),
        ),
      ),
    );
  }

  String _stripLrc(String lrc) {
    final out = <String>[];
    for (final line in lrc.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (RegExp(r'^\[(ti|ar|al|by|offset|re|ve):').hasMatch(trimmed)) continue;
      if (RegExp(r'^\[\d{2}:\d{2}\.\d{2,3}\]$').hasMatch(trimmed)) continue;
      final text = trimmed.replaceAll(RegExp(r'\[\d{2}:\d{2}\.\d{2,3}\]'), '').trim();
      if (text.isNotEmpty) out.add(text);
    }
    return out.join('\n');
  }

  String _fmt(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
