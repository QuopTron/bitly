import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../shared/models/feed_models.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../injection.dart';
import '../../shared/utils/responsive.dart';
import '../../shared/utils/cover_palette.dart';
import '../../shared/widgets/cover_image.dart';

class _KLine {
  final Duration time;
  final String text;
  const _KLine(this.time, this.text);
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
      final text = trimmed.replaceAll(timeRegex, '').trim();
      if (text.isNotEmpty) {
        _lines.add(_KLine(
          Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
          text,
        ));
      }
    }
    if (_lines.isNotEmpty) {
      _lines.sort((a, b) => a.time.compareTo(b.time));
    }
  }

  /// Center-scrolls the active line; only when it actually changes (once per
  /// lyric, not on every position tick).
  void _syncScroll(int newIdx, double viewportH) {
    if (newIdx == _activeIdx && viewportH == _viewportH) return;
    final lineH = 52.0;
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

    return BlocProvider<PlayerCubit>.value(
      value: sl<PlayerCubit>(),
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
            height: height * 0.92,
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
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: r.spacingM),
                    _header(r, isDark),
                    SizedBox(height: r.spacingS),
                    _timeRow(context, r, isDark, player),
                    const SizedBox(height: 4),
                    const Divider(height: 1),
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
                                      itemExtent: 52,
                                      itemCount: _lines.length,
                                      itemBuilder: (context, i) =>
                                          _karaokeLine(r, isDark, i, active, palette),
                                    );
                                  },
                                )
                              : _plainLyrics(r, isDark);
                        },
                      ),
                    ),
                    SizedBox(height: r.bottomPadding),
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
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Transform.scale(
          scale: 1.3,
          child: imageFromUrl(cover, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
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

  Widget _timeRow(BuildContext context, Responsive r, bool isDark, AudioPlayerState player) {
    final fg = isDark ? Colors.white : Colors.black;
    final dur = player.duration;
    final totalMs = dur.inMilliseconds;
    final progress =
        totalMs > 0 ? (player.position.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        SizedBox(width: r.spacingM),
        Text(
          _fmt(player.position),
          style: TextStyle(fontSize: r.footerSize - 1, color: fg.withValues(alpha: 0.5)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: fg.withValues(alpha: 0.7),
              inactiveTrackColor: fg.withValues(alpha: 0.12),
              thumbColor: fg.withValues(alpha: 0.8),
            ),
            child: Slider(
              value: progress,
              onChangeEnd: (v) => sl<PlayerCubit>().seekToProgress(v),
              onChanged: (_) {},
            ),
          ),
        ),
        Text(
          _fmt(dur),
          style: TextStyle(fontSize: r.footerSize - 1, color: fg.withValues(alpha: 0.5)),
        ),
        SizedBox(width: r.spacingM),
      ],
    );
  }

  Widget _karaokeLine(
    Responsive r,
    bool isDark,
    int i,
    int active,
    CoverPalette? palette,
  ) {
    final distance = i - active;
    final fg = isDark ? Colors.white : Colors.black;
    // Smart accent derived from the cover's colors (brand-green fallback
    // until the palette decodes or when there is no cover).
    final accent = palette?.textAccent(onDarkSurface: isDark) ?? fg;

    Color color;
    FontWeight weight;
    double fontSize;
    if (distance == 0) {
      color = accent;
      weight = FontWeight.bold;
      fontSize = r.titleSize;
    } else if (distance > 0 && distance <= 6) {
      // Upcoming lines: cover-tinted, fading to neutral further away.
      color = palette != null
          ? palette.accentForNextLine(onDarkSurface: isDark, distance: distance)
          : Color.lerp(
              fg.withValues(alpha: 0.55),
              accent,
              (0.72 - (distance - 1) * 0.12).clamp(0.05, 0.72),
            )!;
      weight = distance <= 2 ? FontWeight.w600 : FontWeight.w400;
      fontSize = r.subtitleSize + 2;
    } else {
      color = fg.withValues(alpha: distance < 0 ? 0.15 : 0.4);
      weight = FontWeight.w400;
      fontSize = r.subtitleSize;
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
          shadows: distance == 0
              ? [
                  Shadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 10,
                  ),
                ]
              : null,
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
    final fg = isDark ? Colors.white : Colors.black;
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
